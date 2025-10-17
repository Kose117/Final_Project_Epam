# Movie Analyst - Infraestructura AWS

## Descripción
Infraestructura como código para la aplicación Movie Analyst en AWS usando Terraform.

## Arquitectura
- **VPC**: 2 subnets públicas + 2 subnets privadas para la capa de aplicación + 2 subnets privadas para la capa de datos (6 en total, distribuidas en 2 AZs)
- **Frontend**: EC2 en la capa de aplicación (subnet privada AZ-a) con Nginx
- **Backend**: EC2 en la capa de aplicación (Auto Scaling entre ambas subnets privadas)
- **Database**: RDS MySQL en subnets privadas dedicadas a la capa de datos (Multi-AZ opcional)
- **Load Balancer**: ALB público
- **NAT**: Instancia EC2 como NAT (ahorro de costos vs NAT Gateway)
- **Bastion**: Jump server para acceso SSH
- **Monitoring**: CloudWatch dashboards y alarmas

### Diagrama visual de la infraestructura AWS

```mermaid
flowchart LR
    subgraph Internet
        users[Usuarios]
    end

    users -->|HTTP/HTTPS| alb[Application Load Balancer]

    subgraph vpc[VPC (CIDR configurable)]
        direction TB

        subgraph public[Subnets públicas (1 por AZ)]
            direction TB
            subgraph pub_az1[Subnet pública AZ-a]
                alb_eni_a[ENI ALB (AZ-a)]
                bastion[Bastion Host]
                nat[NAT Instance]
            end
            subgraph pub_az2[Subnet pública AZ-b]
                alb_eni_b[ENI ALB (AZ-b)]
            end
            igw[Internet Gateway]
        end

        subgraph app_layer[Capa de aplicación (subnets privadas)]
            direction TB
            subgraph app_az1[Subnet privada App AZ-a]
                fe[EC2 Frontend]
                be1[EC2 Backend (ASG Min 1)]
            end
            subgraph app_az2[Subnet privada App AZ-b]
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

    alb --- alb_eni_a
    alb --- alb_eni_b
    alb -->|Target Group Web| fe
    alb -->|Target Group API| be1
    alb --> be2
    alb -. health checks .-> fe
    alb -. health checks .-> be1
    alb -. health checks .-> be2
    fe -->|Consumo API interno| be1
    fe --> be2
    be1 -->|Consultas SQL| rds_primary
    be2 -->|Consultas SQL| rds_primary
    rds_primary -->|Replica| rds_standby
    bastion -->|SSH privado| fe
    bastion -->|SSH privado| be1
    bastion --> be2
    fe -->|Salida controlada| nat
    be1 -->|Salida controlada| nat
    be2 -->|Salida controlada| nat
    nat -->|Acceso a Internet| igw

    subgraph monitoring[Observabilidad]
        cw[Amazon CloudWatch]
    end

    cw -. métricas .-> alb
    cw -. logs/metrics .-> fe
    cw -. logs/metrics .-> be1
    cw -. logs/metrics .-> be2
    cw -. métricas .-> rds_primary
```

### ¿Cómo se distribuyen los componentes en las subnets privadas?

- **Capa de aplicación** (`app_subnet_cidrs`): aloja frontend y backend. El frontend reside en la subnet de la AZ-a, mientras que el backend escala horizontalmente entre ambas subnets privadas.
- **Capa de datos** (`db_subnet_cidrs`): aloja únicamente RDS. Cada subnet privada está dedicada a la base de datos (primaria y standby) y no comparte recursos con la capa de aplicación.
- **Segmentación**: las rutas por defecto hacia la instancia NAT solo se agregan a las tablas de rutas de la capa de aplicación, lo que evita que la capa de datos tenga salida directa a Internet.

### ¿Cómo se distribuye el Application Load Balancer?

- **Subnets públicas**: el ALB se asocia a las dos subnets públicas (una por AZ); AWS crea un *load balancer node* o ENI por AZ (`alb_eni_a`, `alb_eni_b`) para exponer endpoints redundantes.
- **Target groups**: un grupo para el frontend (Nginx) y otro para el backend (API). Ambos apuntan a instancias en las subnets privadas y se balancean con health checks independientes.
- **Rutas de salida**: el tráfico saliente del ALB (por ejemplo, health checks desde los nodos en cada AZ) recorre la misma subnet pública, mientras que el tráfico hacia Internet usa el Internet Gateway compartido.

> Esta separación por capas ya está implementada en los módulos de Terraform (`app_subnet_cidrs` y `db_subnet_cidrs`) para aislar la base de datos y reducir la superficie de ataque.

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

## Prerequisitos
1. **AWS CLI** configurado con credenciales
2. **Terraform** >= 1.9.0
3. **SSH Key** creada en AWS (región us-east-1)
4. **Tu IP pública** para acceso SSH

## Despliegue inicial

### Paso 1: Crear bucket para Terraform state
```bash
aws s3api create-bucket \
  --bucket <tf-state-bucket> \
  --region us-east-1
```

