# Iniciar el state-bucket-init
Ubicate en la carpeta del modulo
cd /mnt/c/Users/Jose/Documents/Final_Project_Epam/infra/app/state-bucket-init

terraform init
terraform fmt -recursive
terraform validate
terraform plan  -out=plan.tfplan
terraform apply -auto-approve plan.tfplan
terraform destroy -auto-approve

# Nota de permisos
# Este modulo no crea/gestiona recursos IAM. Asegurate de que el usuario
# con el que aplicas (Practical_Test) tenga una policy S3 con permisos minimos
# para crear y administrar el bucket del tfstate y sus objetos.

## Workspaces QA/PROD (tener ambos ambientes activos)

1. Ver el workspace actual
```
terraform workspace list
```

2. Crear y cambiar a workspace de QA (separado de default)
```
terraform workspace new qa
```

3. Aplicar QA (crea recursos NUEVOS, separados de prod)
```
cd infra/root
terraform workspace select qa
terraform apply -var-file=../environments/qa.tfvars
```

4. Crear y cambiar a workspace de produccion
```
terraform workspace new prod
```

5. Aplicar PROD (crea recursos NUEVOS, no toca QA)
```
cd infra/root
terraform apply -var-file=../environments/prod.tfvars
```

6. Alternar entre ambientes
```
# Ir a PROD
terraform workspace select prod

# Volver a QA
terraform workspace select qa
```

> El backend S3 separa los states por workspace (workspace_key_prefix = env).

## Eliminar Workspaces y Recursos

ATENCION: eliminará recursos en AWS. Verifica el workspace antes de ejecutar destroy.

1) Destruir QA y borrar su workspace
```
cd infra/root
terraform workspace list
terraform workspace select qa
terraform destroy -var-file=../environments/qa.tfvars
# Volver a un workspace existente (p.ej., prod) y borrar qa
terraform workspace select prod
terraform workspace delete qa
```

2) Destruir PROD y borrar su workspace
```
cd infra/root
terraform workspace select prod
terraform destroy -var-file=../environments/prod.tfvars
# Cambia a otro workspace existente (p.ej., default) y borra prod
terraform workspace select default
terraform workspace delete prod
```

Notas:
- No se puede borrar el workspace `default`; solo destruir sus recursos.
- Si aparece "Error acquiring the state lock", usa `terraform force-unlock <LOCK_ID>` o `terraform init -reconfigure` y reintenta.

## Eliminar el bucket S3 del Terraform State

Pre-requisitos:
- Haber destruido TODOS los workspaces que guardan state en el bucket.
- El bucket está gestionado por `infra/state-bucket-init` con protecciones activas.

Opción A — Terraform (desproteger temporalmente)
```
cd infra/state-bucket-init
# Editar main.tf (temporal):
#   - aws_s3_bucket.tf_state.force_destroy = true
#   - lifecycle.prevent_destroy = false
terraform init
terraform destroy -auto-approve
```

Opción B — AWS CLI (vaciar y borrar)
```
BUCKET="movie-analyst-tfstate"
aws s3 rm s3://$BUCKET --recursive
aws s3api delete-bucket --bucket $BUCKET --region us-east-1
```

Recomendación: restaura las protecciones (`prevent_destroy=true`, `force_destroy=false`) si vuelves a crear el bucket con Terraform.

## Historial de comandos validados (QA)

# Generar par de llaves y escribir PEM en WSL
terraform init -backend-config=../backend-config/backend.hcl
terraform apply -var-file=../environments/qa.tfvars
terraform apply -var-file=../environments/qa.tfvars -target=module.ssh_key -auto-approve

# Preparar carpeta y permisos en WSL para el PEM
mkdir -p ~/.ssh && chmod 700 ~/.ssh
ls -l ~/.ssh/movie-analyst-wsl2.pem
chmod 600 ~/.ssh/movie-analyst-wsl2.pem

# Crear/actualizar solo Bastion (cuando se rota la clave)
terraform apply -var-file=../environments/qa.tfvars -target=module.bastion -auto-approve

# Conectarse al Bastion (desde WSL)
# Reemplaza <BASTION_IP> con el valor del output "bastion_ip"
ssh -i ~/.ssh/movie-analyst-wsl2.pem ec2-user@<BASTION_IP>

# Agent forwarding para saltar a instancias privadas SIN copiar el PEM
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/movie-analyst-wsl2.pem
ssh -A -i ~/.ssh/movie-analyst-wsl2.pem ec2-user@<BASTION_IP>

# Ya dentro del Bastion, acceso a instancias privadas (SSH directo)
# Reemplaza con los outputs:
#  - frontend_private_ip
#  - backend_hosts (lista)
ssh ec2-user@<FRONTEND_PRIVATE_IP>
ssh ec2-user@<BACKEND_PRIVATE_IP_1>
ssh ec2-user@<BACKEND_PRIVATE_IP_2>

# Verificaciones basicas en cada instancia
sudo ss -ltnp | grep :80 || true
curl -i http://localhost/ || true                # frontend
curl -i http://localhost/api/health || true      # backend



# ------------------------------------------------------------------------------
# COMANDOS DEFINITIVOS (COPIAR/PEGAR) CON PLACEHOLDERS
# Reemplaza los valores entre <> con los outputs actuales:
#   <SSH_KEY_PATH>            Ruta al PEM en tu WSL
#   <BASTION_IP>              bastion_ip
#   <FRONTEND_PRIVATE_IP>     frontend_private_ip
#   <BACKEND_PRIVATE_IP_1/2>  ansible_connection_info.backend_hosts
#   <INTERNAL_ALB_DNS>        internal_alb_dns_name
#   <PUBLIC_ALB_DNS>          alb_dns_name (o ansible_connection_info.public_alb_dns)
#   <RDS_ENDPOINT>            ansible_connection_info.db_host
#   <DB_USER> <DB_PASS> <DB_NAME>
# ------------------------------------------------------------------------------

### Desde WSL - Conectar al Bastion
```
# Iniciar el agente SSH
eval "$(ssh-agent -s)"
# Agregar la clave privada
ssh-add "<SSH_KEY_PATH>"
# Conectar al bastion con agent forwarding
ssh -A -i "<SSH_KEY_PATH>" ec2-user@<BASTION_IP>
```

### En el Bastion - Configurar Ansible
```
# Crear estructura de directorios
mkdir -p ~/ansible/inventory ~/ansible/playbooks

# Crear archivo de inventario
tee ~/ansible/inventory/hosts >/dev/null <<'H'
[frontend]
<FRONTEND_PRIVATE_IP>

[backend]
<BACKEND_PRIVATE_IP_1>
<BACKEND_PRIVATE_IP_2>

[all:vars]
ansible_user=ec2-user
H

# Verificar conectividad
ansible all -i ~/ansible/inventory/hosts -m ping

3 yes seguidos
```

### Crear Playbook Frontend (ui.yml)
```
sudo yum install nano
nano ~/ansible/playbooks/ui.yml
```
Contenido (pegar tal cual):
```
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

    - name: Instalar deps UI (npm install porque no hay package-lock)
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

### Crear Playbook Backend (api.yml)
```
nano ~/ansible/playbooks/api.yml
```
Contenido (pegar tal cual):
```
- hosts: backend
  become: true
  vars:
    repo_url: https://github.com/Kose117/devops-rampup.git
    app_dir: /opt/movie-analyst
    api_dir: /opt/movie-analyst/movie-analyst-api
    db_host: "<RDS_ENDPOINT>"
    db_user: "<DB_USER>"
    db_pass: "<DB_PASS>"
    db_name: "<DB_NAME>"
    api_port: "80"
  tasks:
    - name: Ensure packages (reintentos)
      shell: |
        for i in $(seq 1 20); do dnf -y install nodejs git mariadb105 || dnf -y install nodejs git mysql && exit 0 || sleep 15; done; exit 1

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

    - name: Instalar deps API (npm install porque no hay package-lock)
      shell: npm install --production --no-audit --no-fund
      args:
        chdir: "{{ api_dir }}"

    - name: Cargar schema en RDS (idempotente)
      shell: |
        mysql -h "{{ db_host }}" -u "{{ db_user }}" -p"{{ db_pass }}" "{{ db_name }}" < "{{ api_dir }}/schema.sql"
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

### Ejecutar Playbooks
```
# Frontend
ansible-playbook -i ~/ansible/inventory/hosts ~/ansible/playbooks/ui.yml
# Backend
ansible-playbook --ask-vault-pass -i ~/ansible/inventory/hosts ~/ansible/playbooks/api.yml
```

### Verificar Deployment
```
# Frontend
ssh ec2-user@<FRONTEND_PRIVATE_IP>
sudo systemctl status movie-analyst-ui --no-pager
exit

# Backend (ejemplo primer backend)
ssh ec2-user@<BACKEND_PRIVATE_IP_1>
sudo systemctl status movie-analyst-api --no-pager
exit

# Endpoints
echo "Frontend:"; curl -i http://<PUBLIC_ALB_DNS>/
echo "Backend (desde bastion o privada):"; curl -i http://<INTERNAL_ALB_DNS>/api/health
```

# ------------------------------------------------------------------------------
# SECCION ACTUALIZADA (Outputs y Playbook Backend con Vault)
# ------------------------------------------------------------------------------

## Output unificado (deployment_guide)
Tras `terraform apply`, imprime los pasos listos:
```
cd infra/root
terraform output deployment_guide
```

## Backend con Ansible Vault (DB_PASS)
1) Crear secreto Vault y guardarlo
```
mkdir -p ~/ansible/vars
ansible-vault create ~/ansible/vars/secret.yml
# Contenido exacto dentro del editor:
# vault_db_pass: "<TU_DB_PASS>"
# Para guardar y salir: Esc, :wq, Enter
```

2) Playbook API (actualizado)
```
nano ~/ansible/playbooks/api.yml
```
Pega:
```
- hosts: backend
  become: true
  vars_files:
    - /home/ec2-user/ansible/vars/secret.yml
  vars:
    repo_url: https://github.com/Kose117/devops-rampup.git
    app_dir: /opt/movie-analyst
    api_dir: /opt/movie-analyst/movie-analyst-api
    db_host: "<RDS_ENDPOINT>"
    db_user: "<DB_USER>"
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

  - name: Instalar dependencias API (npm install)
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

  - name: Ajustar columna release -> release_year (idempotente)
    shell: |
      mysql -h "{{ db_host }}" -u "{{ db_user }}" -p"{{ db_pass }}" -D "{{ db_name }}" -e "ALTER TABLE movies CHANGE \`release\` \`release_year\` VARCHAR(250) NOT NULL;"
    register: alter_out
    failed_when: false
    changed_when: alter_out.rc == 0

  - name: Seed DB (idempotente)
    shell: |
      DB_HOST="{{ db_host }}" DB_USER="{{ db_user }}" DB_PASS="{{ db_pass }}" DB_NAME="{{ db_name }}" node "{{ api_dir }}/seeds.js"
    args:
      creates: "/var/lib/.seeds_loaded"
    register: seeds_out
    changed_when: seeds_out.rc == 0
    failed_when: false

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

3) Ejecutar
```
ansible-playbook --ask-vault-pass -i ~/ansible/inventory/hosts ~/ansible/playbooks/api.yml
```
