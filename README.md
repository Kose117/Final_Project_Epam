# Movie Analyst - Infraestructura AWS

## Descripción
Infraestructura como código para la aplicación Movie Analyst en AWS usando Terraform.

## Arquitectura
- **VPC**: 2 subnets públicas + 2 subnets privadas para la capa de aplicación + 2 subnets privadas para la capa de datos (6 en total, distribuidas en 2 AZs)
- **Frontend**: EC2 en la capa de aplicación (subnet privada AZ-a) con Nginx
- **Backend**: EC2 en la capa de aplicación (Auto Scaling entre ambas subnets privadas)
- **Database**: RDS MySQL en subnets privadas dedicadas a la capa de datos (Multi-AZ opcional)
- **Load Balancer**: ALB público (frontend) + ALB interno (backend)
- **NAT**: Instancia EC2 como NAT (ahorro de costos vs NAT Gateway)
- **Bastion**: Jump server para acceso SSH
- **Monitoring**: CloudWatch dashboards y alarmas

### Diagrama visual de la infraestructura AWS

```mermaid
flowchart LR
    subgraph Internet
        users[Usuarios]
    end

    users -->|HTTP/HTTPS| alb_public[Application Load Balancer (público)]

    subgraph vpc[VPC (CIDR configurable)]
        direction TB

        subgraph public[Subnets públicas (1 por AZ)]
            direction TB
            subgraph pub_az1[Subnet pública AZ-a]
                alb_eni_a[ENI ALB público (AZ-a)]
                bastion[Bastion Host]
                nat[NAT Instance]
            end
            subgraph pub_az2[Subnet pública AZ-b]
                alb_eni_b[ENI ALB público (AZ-b)]
            end
            igw[Internet Gateway]
        end

        subgraph frontend_layer[Capa de frontend (subnets privadas)]
            direction TB
            subgraph fe_az1[Subnet privada Frontend AZ-a]
                fe[EC2 Frontend]
            end
            subgraph fe_az2[Subnet privada Frontend AZ-b]
                fe_placeholder[(Slot para FE adicional)]
            end
        end

        subgraph backend_layer[Capa de backend (subnets privadas)]
            direction TB
            alb_internal[(ALB Interno Backend)]
            subgraph be_az1[Subnet privada Backend AZ-a]
                alb_int_eni_a[ENI ALB interno (AZ-a)]
                be1[EC2 Backend (ASG Min 1)]
            end
            subgraph be_az2[Subnet privada Backend AZ-b]
                alb_int_eni_b[ENI ALB interno (AZ-b)]
                be2[EC2 Backend (ASG Max n)]
            end
        end

        subgraph db_layer[Capa de datos (subnets privadas)]
            direction TB
            subgraph db_az1[Subnet privada DB AZ-a]
                rds_primary[(RDS MySQL - primario)]
            end
            subgraph db_az2[Subnet privada DB AZ-b]
                rds_standby[(RDS MySQL - standby)]
            end
        end
    end

    alb_public --- alb_eni_a
    alb_public --- alb_eni_b
    alb_public -->|Target Group Web| fe
    alb_public -. health checks .-> fe
    fe -->|HTTP interno /api/*| alb_internal
    alb_internal --- alb_int_eni_a
    alb_internal --- alb_int_eni_b
    alb_internal -->|Target Group Backend| be1
    alb_internal --> be2
    alb_internal -. health checks .-> be1
    alb_internal -. health checks .-> be2
    be1 -->|Consultas SQL| rds_primary
    be2 -->|Consultas SQL| rds_primary
    rds_primary -->|Replica| rds_standby
    bastion -->|SSH privado| fe
    bastion -->|SSH privado| be1
    bastion --> be2
    fe -->|Salida controlada| nat
    fe_placeholder -->|Salida controlada| nat
    be1 -->|Salida controlada| nat
    be2 -->|Salida controlada| nat
    nat -->|Acceso a Internet| igw

    subgraph monitoring[Observabilidad]
        cw[Amazon CloudWatch]
    end

    cw -. métricas .-> alb_public
    cw -. métricas .-> alb_internal
    cw -. logs/metrics .-> fe
    cw -. logs/metrics .-> be1
    cw -. logs/metrics .-> be2
    cw -. métricas .-> rds_primary
```

### ¿Cómo se distribuyen los componentes en las subnets privadas?

- **Capa de frontend** (`frontend_subnet_cidrs`): aloja exclusivamente la instancia que sirve el sitio web. Cada AZ recibe su propia subnet para que el ALB público pueda enrutar hacia instancias redundantes si decides escalar horizontalmente.
- **Capa de backend** (`backend_subnet_cidrs`): alberga las instancias de la API y el ALB interno. El tráfico queda aislado del frontend salvo por el security group que autoriza las llamadas `/api/*`.
- **Capa de datos** (`db_subnet_cidrs`): aloja únicamente RDS. Cada subnet privada está dedicada a la base de datos (primaria y standby) y no comparte recursos con otras capas.
- **Segmentación**: las rutas por defecto hacia la instancia NAT solo se agregan a las tablas de rutas de frontend y backend, lo que evita que la capa de datos tenga salida directa a Internet.

### ¿Cómo se distribuyen los Application Load Balancers?

- **ALB público (frontend)**: se asocia a las dos subnets públicas (una por AZ) y expone únicamente el sitio web. Sus target groups apuntan sólo a la instancia frontend; no enruta tráfico a la API.
- **ALB interno (backend)**: reside en las subnets privadas de la capa de backend. Recibe tráfico únicamente desde el security group del frontend (y del bastion para tareas operativas) y reparte las peticiones `/api/*` entre las instancias backend.
- **Flujo de peticiones**: el usuario llega al ALB público → el frontend atiende la solicitud y, cuando necesita datos, llama al ALB interno usando su DNS privado (`BACKEND_ORIGIN` en el servicio Node.js).
- **Rutas de salida**: ambos ALB usan sus propias subnets para health checks; sólo el ALB público tiene salida al Internet Gateway.

> Esta separación por capas ya está implementada en los módulos de Terraform (`frontend_subnet_cidrs`, `backend_subnet_cidrs` y `db_subnet_cidrs`) para aislar la base de datos, minimizar el *blast radius* y evitar patrones de hairpin NAT.

## Decisiones de diseño

### ¿Por qué NAT Instance en vez de NAT Gateway?
- **Costo**: NAT Gateway ~$32/mes, NAT Instance t3.micro ~$7/mes
- **Free tier**: t3.micro incluido en free tier
- **Requisito**: Cliente con restricciones de presupuesto

### ¿Por qué módulos propios en vez de públicos?
- Control total sobre la configuración
- Reutilización interna del equipo
- Facilita mantenimiento y debugging

### ¿Por qué RDS en vez de MySQL en EC2?
- Backups automáticos
- Alta disponibilidad (Multi-AZ opcional)
- Parches automáticos
- Mejor práctica AWS Well-Architected

## Prerrequisitos
Antes de aplicar la infraestructura desde WSL necesitas:

1. **Cuenta AWS y usuario IAM con permisos de administrador** (o un rol que permita crear VPC, EC2, RDS, ALB, etc.).
2. **AWS CLI v2** instalada y configurada (`aws configure`).
3. **Terraform ≥ 1.9** instalado.
4. **Key Pair de EC2** en la región `us-east-1` para poder conectarte por SSH.
5. **Tu IP pública** para restringir el acceso al bastion (`allowed_ssh_cidrs`).
6. **Una contraseña segura para la base de datos** que exportarás como variable de entorno (`TF_VAR_db_password`).

> Si necesitas instalar Terraform o AWS CLI en WSL, sigue las instrucciones del intercambio anterior o consulta la documentación oficial de HashiCorp/AWS.

## Despliegue inicial

### Paso 1: Crear bucket para el estado remoto de Terraform
El bucket debe tener un nombre globalmente único. Sustituye `movie-analyst-tfstate-<tu-inicial>` por un nombre propio:

```bash
BUCKET_NAME="movie-analyst-tfstate-$(whoami)"

# Comprueba que el nombre esté libre
aws s3api head-bucket --bucket "$BUCKET_NAME" 2>&1 | grep -q 'Not Found'

# Crea el bucket en us-east-1
aws s3api create-bucket \
  --bucket "$BUCKET_NAME" \
  --region us-east-1 \
  --create-bucket-configuration LocationConstraint=us-east-1
```

Actualiza `infra/backend-config/backend.hcl` con el nombre real del bucket (`bucket = "..."`).

### Paso 2: Crear (o importar) un Key Pair de EC2
Puedes crearlo desde la consola (EC2 → Network & Security → Key Pairs → Create key pair) o desde la CLI:

```bash
KEY_NAME="movie-analyst-wsl"

aws ec2 create-key-pair \
  --key-name "$KEY_NAME" \
  --key-type rsa \
  --query 'KeyMaterial' \
  --output text > "$HOME/.ssh/${KEY_NAME}.pem"

chmod 400 "$HOME/.ssh/${KEY_NAME}.pem"
```

Toma nota del nombre (`movie-analyst-wsl` en el ejemplo) porque lo usarás en `ssh_key_name`.

### Paso 3: Obtener tu IP pública para `allowed_ssh_cidrs`
Desde WSL ejecuta:

```bash
curl ifconfig.me
```

Si la salida es `203.0.113.25`, la notación CIDR sería `203.0.113.25/32`. Usa esta cadena en la variable `allowed_ssh_cidrs` para limitar el acceso SSH al bastion.

### Paso 4: Definir la contraseña de la base de datos

En lugar de generar una contraseña aleatoria, define directamente una contraseña fuerte.  

```bash
export TF_VAR_db_password="Josemanuel2003*"

### Paso 5: Copiar el template de variables y personalizarlo

```bash
cd /ruta/al/repositorio/infra/root
cp terraform.tfvars ../environments/qa.tfvars   # o prod.tfvars según el entorno
```

Edita el archivo `infra/environments/qa.tfvars` (o `prod.tfvars`) y reemplaza:

- `ssh_key_name` por el nombre exacto del Key Pair creado en el Paso 2.
- `allowed_ssh_cidrs` por tu IP en formato `/32` obtenida en el Paso 3.
- Ajusta `backend_instance_count`, `instance_type` y los CIDR si necesitas otra topología.

> Si prefieres no guardar la contraseña en el `.tfvars`, elimina la línea `db_password = ...` del archivo y confía únicamente en `export TF_VAR_db_password=...`.

### Paso 6: Inicializar y aplicar Terraform
```
terraform init -backend-config=../backend-config/backend.hcl
terraform workspace new qa   # solo la primera vez
terraform workspace select qa
terraform plan  -var-file=../environments/qa.tfvars
terraform apply -var-file=../environments/qa.tfvars
```

### Paso 7: Configurar el frontend con el ALB interno del backend
Después del `terraform apply`, obtén `internal_alb_dns_name` del output. Ese valor debe inyectarse como `BACKEND_ORIGIN` en el servicio Node.js (por ejemplo `http://internal-alb-1234.us-east-1.elb.amazonaws.com`). Puedes hacerlo vía variable de entorno, archivo `.env` o mediante `user_data` en la instancia frontend.

