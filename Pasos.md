# Movie Analyst - Infrastructure Deployment Guide

## 📋 Tabla de Contenidos

1. [Inicialización del Backend S3](#1-inicialización-del-backend-s3)
2. [Gestión de Workspaces](#2-gestión-de-workspaces-qadefaultprod)
3. [Deployment con Terraform](#3-deployment-con-terraform)
4. [Configuración de Ansible](#4-configuración-de-ansible)
5. [Ansible Vault (Seguridad)](#5-ansible-vault-seguridad)
6. [Verificación del Deployment](#6-verificación-del-deployment)
7. [Limpieza de Recursos](#7-limpieza-de-recursos)
8. [Troubleshooting](#8-troubleshooting)

---

## 1. Inicialización del Backend S3

### 1.1 Crear el bucket para el Terraform State

```bash
# Navegar al módulo de inicialización
cd infra/state-bucket-init

# Inicializar y aplicar
terraform init
terraform fmt -recursive
terraform validate
terraform plan -out=plan.tfplan
terraform apply -auto-approve plan.tfplan
```

### 1.2 Nota sobre permisos

Este módulo NO crea/gestiona recursos IAM. Asegúrate de que tu usuario AWS tenga permisos mínimos para:
- Crear y administrar buckets S3
- Gestionar objetos del tfstate
- Aplicar políticas de bucket

### 1.3 Eliminar el bucket (si es necesario)

**⚠️ ADVERTENCIA:** Solo ejecutar después de destruir TODOS los workspaces.

**Opción A - Con Terraform:**

```bash
cd infra/state-bucket-init

# 1. Editar main.tf temporalmente:
#    - aws_s3_bucket.tf_state.force_destroy = true
#    - lifecycle.prevent_destroy = false

# 2. Destruir
terraform init
terraform destroy -auto-approve

# 3. Restaurar protecciones en main.tf
```

**Opción B - Con AWS CLI:**

```bash
BUCKET="movie-analyst-tfstate-equipodemo"
aws s3 rm s3://$BUCKET --recursive
aws s3api delete-bucket --bucket $BUCKET --region us-east-1
```

---

## 2. Gestión de Workspaces (QA/Default/Prod)

### 2.1 Comandos básicos de workspaces

```bash
# Ver workspace actual
terraform workspace list

# Crear un nuevo workspace
terraform workspace new <nombre>

# Cambiar de workspace
terraform workspace select <nombre>
```

### 2.2 Crear y desplegar QA

```bash
cd infra/app/root

# Crear workspace de QA
terraform workspace new qa

# Inicializar con el backend remoto
terraform init -backend-config=../backend-config/backend.hcl

# Aplicar configuración de QA
terraform apply -var-file=../environments/qa.tfvars
```

### 2.3 Crear y desplegar Producción

```bash
cd infra/app/root

# Crear workspace de producción
terraform workspace new prod

# Inicializar con el backend remoto
terraform init -backend-config=../backend-config/backend.hcl

# Aplicar configuración de producción
terraform apply -var-file=../environments/prod.tfvars
```

### 2.4 Alternar entre ambientes

```bash
# Ir a producción
terraform workspace select prod

# Volver a QA
terraform workspace select qa

# Ver configuración aplicada
terraform show
```

> **Nota:** El backend S3 separa los states por workspace usando `workspace_key_prefix = "env"`.

---

## 3. Deployment con Terraform

### 3.1 Deployment completo de QA

```bash
cd infra/root
terraform workspace select qa
terraform init -backend-config=../backend-config/backend.hcl
terraform apply -var-file=../environments/qa.tfvars
```

### 3.2 Preparar SSH Key en WSL

```bash
# Crear carpeta y ajustar permisos
mkdir -p ~/.ssh && chmod 700 ~/.ssh

# Verificar que el PEM se creó
ls -l ~/.ssh/movie-analyst-wsl2.pem

# Ajustar permisos
chmod 600 ~/.ssh/movie-analyst-wsl2.pem
```

### 3.3 Deployment incremental (solo componentes específicos)

```bash
# Solo el SSH key
terraform apply -var-file=../environments/qa.tfvars -target=module.ssh_key -auto-approve

# Solo el Bastion (útil cuando rotas claves)
terraform apply -var-file=../environments/qa.tfvars -target=module.bastion -auto-approve
```

### 3.4 Ver outputs del deployment

```bash
# Ver guía completa de deployment
terraform output deployment_guide

# Ver outputs específicos
terraform output bastion_ip
terraform output alb_dns_name
```

---

## 4. Configuración de Ansible

### 4.1 Conectar al Bastion (desde WSL)

```bash
# Iniciar el agente SSH
eval "$(ssh-agent -s)"

# Agregar la clave privada
ssh-add "/home/kose117/.ssh/movie-analyst-wsl2.pem"

# Conectar con agent forwarding (-A permite saltar a instancias privadas)
ssh -A -i "/home/kose117/.ssh/movie-analyst-wsl2.pem" ec2-user@<BASTION_IP>
```

### 4.2 Configurar estructura de Ansible

```bash
# Ya en el Bastion, crear directorios
mkdir -p ~/ansible/inventory ~/ansible/playbooks ~/ansible/vars

# Instalar nano (opcional, para editar archivos)
sudo dnf install -y nano
```

### 4.3 Crear inventario de Ansible

```bash
tee ~/ansible/inventory/hosts >/dev/null <<'H'
[frontend]
<FRONTEND_PRIVATE_IP>

[backend]
<BACKEND_PRIVATE_IP_1>
<BACKEND_PRIVATE_IP_2>

[all:vars]
ansible_user=ec2-user
H
```

**Reemplaza los placeholders:**
- `<FRONTEND_PRIVATE_IP>`: Usar output `frontend_private_ip`
- `<BACKEND_PRIVATE_IP_1/2>`: Usar outputs `ansible_connection_info.backend_hosts`

### 4.4 Verificar conectividad

```bash
ansible all -i ~/ansible/inventory/hosts -m ping

# Esperado: 3 respuestas "SUCCESS" (1 frontend + 2 backends)
```

---

## 5. Ansible Vault (Seguridad)

### 5.1 Crear archivo cifrado para la contraseña de DB

```bash
# Crear directorio para secretos
mkdir -p ~/ansible/vars

# Crear archivo cifrado (te pedirá una contraseña de Vault)
ansible-vault create ~/ansible/vars/secret.yml
```

**Dentro del editor que se abre, escribe:**

```yaml
vault_db_pass: "<Password>"
```

**Guardar y salir:**
- Presiona `i` (modo inserción)
- Escribe el contenido
- Presiona `ESC`
- Escribe `:wq` y presiona `Enter`


### 5.2 Comandos útiles de Vault

```bash
# Ver contenido descifrado
ansible-vault view ~/ansible/vars/secret.yml --vault-password-file ~/ansible/.vault_pass

# Editar el secreto
ansible-vault edit ~/ansible/vars/secret.yml --vault-password-file ~/ansible/.vault_pass

# Cambiar la contraseña del Vault
ansible-vault rekey ~/ansible/vars/secret.yml --vault-password-file ~/ansible/.vault_pass
```

---

## 6. Deployment de Aplicaciones

### 6.1 Playbook Frontend (UI)

```bash
nano ~/ansible/playbooks/ui.yml
```

**Contenido:**

```yaml
- hosts: frontend
  become: true
  vars:
    repo_url: https://github.com/Kose117/devops-rampup.git
    app_dir: /opt/movie-analyst
    ui_dir: /opt/movie-analyst/movie-analyst-ui
    fe_port: "80"
    backend_origin: "http://<INTERNAL_ALB_DNS>"
  tasks:
    - name: Ensure packages (reintentos)
      shell: |
        for i in $(seq 1 20); do dnf -y install nodejs git && exit 0 || sleep 15; done; exit 1

    - name: Crear carpeta base
      file:
        path: "{{ app_dir }}"
        state: directory
        mode: '0755'

    - name: Obtener repo completo
      git:
        repo: "{{ repo_url }}"
        dest: "{{ app_dir }}"
        version: HEAD
        force: yes

    - name: Instalar deps UI (npm install)
      shell: npm install --production --no-audit --no-fund
      args:
        chdir: "{{ ui_dir }}"

    - name: Systemd service para movie-analyst-ui
      copy:
        dest: /etc/systemd/system/movie-analyst-ui.service
        mode: '0644'
        content: |
          [Unit]
          Description=Movie Analyst UI
          After=network-online.target

          [Service]
          Type=simple
          WorkingDirectory={{ ui_dir }}
          Environment=PORT={{ fe_port }}
          Environment=BACKEND_ORIGIN={{ backend_origin }}
          ExecStart=/usr/bin/node server.js
          Restart=always
          RestartSec=2
          AmbientCapabilities=CAP_NET_BIND_SERVICE
          CapabilityBoundingSet=CAP_NET_BIND_SERVICE
          NoNewPrivileges=true

          [Install]
          WantedBy=multi-user.target

    - name: Recargar systemd y arrancar servicio
      systemd:
        daemon_reload: true
        name: movie-analyst-ui
        state: restarted
        enabled: true
```

**Reemplazar:** `<INTERNAL_ALB_DNS>` con el output `internal_alb_dns_name`

**Ejecutar:**

```bash
ansible-playbook -i ~/ansible/inventory/hosts ~/ansible/playbooks/ui.yml
```

### 6.2 Playbook Backend (API) con Vault

```bash
nano ~/ansible/playbooks/api.yml
```

**Contenido:**

```yaml
- hosts: backend
  become: true
  vars_files:
    - /home/ec2-user/ansible/vars/secret.yml
  vars:
    repo_url: https://github.com/Kose117/devops-rampup.git
    app_dir: /opt/movie-analyst
    api_dir: /opt/movie-analyst/movie-analyst-api
    db_host: "<RDS_ENDPOINT>"
    db_user: "appuser"
    db_pass: "{{ vault_db_pass }}"
    db_name: "movie_db"
    api_port: "80"
  tasks:
    - name: Ensure packages (reintentos)
      shell: |
        for i in $(seq 1 20); do dnf -y install nodejs git mariadb105 && exit 0 || sleep 15; done; exit 1

    - name: Crear carpeta base
      file:
        path: "{{ app_dir }}"
        state: directory
        mode: '0755'

    - name: Obtener repo completo
      git:
        repo: "{{ repo_url }}"
        dest: "{{ app_dir }}"
        version: HEAD
        force: yes

    - name: Instalar deps API (npm install)
      shell: npm install --production --no-audit --no-fund
      args:
        chdir: "{{ api_dir }}"

    - name: Load DB schema en RDS (idempotente)
      shell: |
        mysql -h "{{ db_host }}" -u "{{ db_user }}" -p"{{ db_pass }}" < "{{ api_dir }}/schema.sql"
      args:
        creates: "/var/lib/.schema_loaded"
      register: schema_out
      changed_when: schema_out.rc == 0
      failed_when: false

    - name: Marcar schema loaded
      file:
        path: /var/lib/.schema_loaded
        state: touch
        mode: '0644'

    - name: Seed DB (idempotente)
      shell: |
        DB_HOST="{{ db_host }}" DB_USER="{{ db_user }}" DB_PASS="{{ db_pass }}" DB_NAME="{{ db_name }}" node "{{ api_dir }}/seeds.js"
      args:
        creates: "/var/lib/.seeds_loaded"
      register: seeds_out
      changed_when: seeds_out.rc == 0
      failed_when: false

    - name: Marcar seeds loaded
      file:
        path: /var/lib/.seeds_loaded
        state: touch
        mode: '0644'

    - name: Systemd service para movie-analyst-api
      copy:
        dest: /etc/systemd/system/movie-analyst-api.service
        mode: '0644'
        content: |
          [Unit]
          Description=Movie Analyst API
          After=network-online.target

          [Service]
          Type=simple
          WorkingDirectory={{ api_dir }}
          Environment=PORT={{ api_port }}
          Environment=DB_HOST={{ db_host }}
          Environment=DB_USER={{ db_user }}
          Environment=DB_PASS={{ db_pass }}
          Environment=DB_NAME={{ db_name }}
          ExecStart=/usr/bin/node server.js
          Restart=always
          RestartSec=2
          AmbientCapabilities=CAP_NET_BIND_SERVICE
          CapabilityBoundingSet=CAP_NET_BIND_SERVICE
          NoNewPrivileges=true

          [Install]
          WantedBy=multi-user.target

    - name: Recargar systemd y arrancar API
      systemd:
        daemon_reload: true
        name: movie-analyst-api
        state: restarted
        enabled: true
```

**Reemplazar:** `<RDS_ENDPOINT>` con el output `ansible_connection_info.db_host`

**Ejecutar:**

```bash
# Con Vault password interactivo
ansible-playbook --ask-vault-pass -i ~/ansible/inventory/hosts ~/ansible/playbooks/api.yml

# O con archivo de contraseña (si configuraste el paso 5.2)
ansible-playbook -i ~/ansible/inventory/hosts ~/ansible/playbooks/api.yml
```

---

## 7. Verificación del Deployment

### 7.1 Verificar servicios en las instancias

```bash
# Verificar Frontend
ssh ec2-user@<FRONTEND_PRIVATE_IP>
sudo systemctl status movie-analyst-ui --no-pager
curl -i http://localhost/
exit

# Verificar Backend (primer servidor)
ssh ec2-user@<BACKEND_PRIVATE_IP_1>
sudo systemctl status movie-analyst-api --no-pager
curl -i http://localhost/api/health
curl -i http://localhost/api/movies
exit
```

### 7.2 Verificar endpoints públicos e internos

```bash
# Desde el Bastion, probar ALB interno
curl -i http://<INTERNAL_ALB_DNS>/api/health
curl -i http://<INTERNAL_ALB_DNS>/api/movies

# Desde WSL, probar ALB público
curl -i http://<PUBLIC_ALB_DNS>/

# O abrir en navegador
# http://<PUBLIC_ALB_DNS>/
```

### 7.3 Verificar Target Groups en AWS Console

1. Ve a **EC2 > Target Groups**
2. Busca:
   - `movie-analyst-qa-tg-frontend` → Debe estar **Healthy**
   - `movie-analyst-qa-be-tg-int` → Ambos backends deben estar **Healthy**
3. Si están **Unhealthy**, espera 60-120 segundos para que se marquen como Healthy

### 7.4 Ver logs en CloudWatch

```bash
# URL del dashboard (desde los outputs de Terraform)
# https://console.aws.amazon.com/cloudwatch/home?region=us-east-1#dashboards:name=movie-analyst-qa-dashboard
```

---

## 8. Limpieza de Recursos

### 8.1 Destruir workspace de QA

```bash
cd infra/root

# Asegurarse de estar en el workspace correcto
terraform workspace list
terraform workspace select qa

# Destruir recursos de QA
terraform destroy -var-file=../environments/qa.tfvars

# Cambiar a otro workspace antes de borrar
terraform workspace select default
terraform workspace delete qa
```

### 8.2 Destruir workspace de Producción

```bash
cd infra/root

terraform workspace select prod
terraform destroy -var-file=../environments/prod.tfvars

# Cambiar a default y borrar prod
terraform workspace select default
terraform workspace delete prod
```

**⚠️ Notas importantes:**
- No se puede borrar el workspace `default`; solo destruir sus recursos
- Si aparece "Error acquiring the state lock", usa:
  ```bash
  terraform force-unlock <LOCK_ID>
  # O
  terraform init -reconfigure
  ```

---

## 9. Troubleshooting

### 9.1 Bad Gateway (502) en el ALB

**Causas comunes:**
1. Target Groups no están Healthy
2. El servicio backend no está corriendo
3. Problema de conectividad frontend → backend

**Diagnóstico:**

```bash
# Conectar al backend y revisar logs
ssh ec2-user@<BACKEND_PRIVATE_IP>
sudo journalctl -u movie-analyst-api -n 100 --no-pager

# Ver si está escuchando en puerto 80
sudo ss -ltnp | grep :80

# Probar localmente
curl -i http://localhost/api/health
```

### 9.2 Error de conexión SSH

**Si falla el agent forwarding:**

```bash
# Verificar que el agente está corriendo
ssh-add -l

# Si no lista la clave, agregarla de nuevo
ssh-add "/home/kose117/.ssh/movie-analyst-wsl2.pem"
```

### 9.3 Error de Ansible: "Unable to connect"

```bash
# Verificar conectividad desde el bastion
ansible all -i ~/ansible/inventory/hosts -m ping

# Si falla, verificar que las IPs del inventario son correctas
cat ~/ansible/inventory/hosts

# Probar SSH manual
ssh ec2-user@<IP_PRIVADA>
```

### 9.4 Vault password incorrect

```bash
# Verificar la contraseña del archivo
cat ~/ansible/.vault_pass

# Intentar descifrar manualmente
ansible-vault view ~/ansible/vars/secret.yml --vault-password-file ~/ansible/.vault_pass
```

### 9.5 RDS connection refused

```bash
# Verificar Security Groups en AWS Console
# El RDS debe permitir puerto 3306 desde:
# - Backend SG
# - Bastion SG

# Probar conexión desde el bastion
mysql -h <RDS_ENDPOINT> -u appuser -p'<Password>'
```

---