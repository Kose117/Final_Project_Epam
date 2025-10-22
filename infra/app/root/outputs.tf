# ==============================================================================
# OUTPUTS - Root Module
# ==============================================================================
# Informacion importante que se muestra despues de terraform apply
# ==============================================================================

## Eliminados outputs redundantes (alb_dns_name, internal_alb_dns_name, bastion_ip, cloudwatch_dashboard)

# ------------------------------------------------------------------------------
# IPs Privadas (para Ansible)
# ------------------------------------------------------------------------------
output "frontend_private_ip" {
  value       = module.frontend.private_ip
  description = "IP privada del servidor frontend"
  sensitive   = true # Consolidado en deployment_guide
}

# Removido: backend_private_ip ya no existe (ahora es backend_private_ips)

# ------------------------------------------------------------------------------
# Base de Datos
# ------------------------------------------------------------------------------
output "rds_endpoint" {
  value       = module.rds.endpoint
  description = "Endpoint de conexion a RDS MySQL"
  sensitive   = true
}

# ------------------------------------------------------------------------------
# Informacion para Ansible (Human Readable)
# ------------------------------------------------------------------------------
## Eliminado ansible_connection_info en favor de un unico bloque mas legible

# ------------------------------------------------------------------------------
# Instrucciones Post-Deploy
# ------------------------------------------------------------------------------
## Eliminado next_steps (fusionado en deployment_guide)

output "ssh_private_key_path" {
  value       = module.ssh_key.private_key_path
  description = "Ruta local del archivo PEM generado para el acceso SSH"
  sensitive   = true # Consolidado en deployment_guide
}

# ------------------------------------------------------------------------------
# Quickstart Commands - Ready to copy/paste
# ------------------------------------------------------------------------------
## Reemplazado por deployment_guide (fusionado y legible)

# ------------------------------------------------------------------------------
# Deployment Guide (fusionado: resumen + comandos listos para seguir)
# ------------------------------------------------------------------------------
output "deployment_guide" {
  value = <<-EOT
  #--------- RESUMEN ----------
  Workspace:  ${terraform.workspace}
  Environment:${var.environment}
  Region:     ${var.region}

  Bastion:
    - SSH User: ec2-user
    - Public IP: ${module.bastion.public_ip}
    - SSH Key:   ${module.ssh_key.private_key_path}

  Endpoints:
    - Public ALB:   http://${module.alb_public.alb_dns_name}
    - Internal ALB: http://${module.alb_internal.alb_dns_name}
    - RDS Endpoint: ${module.rds.endpoint}
    - CloudWatch:   https://console.aws.amazon.com/cloudwatch/home?region=${var.region}#dashboards:name=${module.monitoring.dashboard_name}

  Hosts Privados:
    - Frontend: ${module.frontend.private_ip}
    - Backends: ${join(", ", module.backend.private_ips)}

  #--------- 1) SSH Agent + Bastion (WSL) ----------
  eval "$(ssh-agent -s)"
  ssh-add "${module.ssh_key.private_key_path}"
  ssh -A -i "${module.ssh_key.private_key_path}" ec2-user@${module.bastion.public_ip}

  #--------- 2) Inventario Ansible ----------
  mkdir -p ~/ansible/inventory ~/ansible/playbooks
  tee ~/ansible/inventory/hosts >/dev/null <<'H'
  [frontend]
  ${module.frontend.private_ip}

  [backend]
  ${join("\n", module.backend.private_ips)}

  [all:vars]
  ansible_user=ec2-user
H
  ansible all -i ~/ansible/inventory/hosts -m ping

  #--------- 2.5) Configurar Ansible Vault (DB_PASS) ----------
  # Crea un archivo cifrado con la contraseña de la base de datos
  mkdir -p ~/ansible/vars
  # Al ejecutar el siguiente comando, ingresa una contraseña de Vault y edita el contenido
  # para que sea exactamente:
  #   vault_db_pass: "<TU_DB_PASS>"
  # Guardar y salir en vi/vim: presiona Esc, escribe :wq y Enter
  ansible-vault create ~/ansible/vars/secret.yml

  # Ver el archivo cifrado (veras texto encriptado)
  cat ~/ansible/vars/secret.yml

  # Ver el contenido descifrado (pedira la clave de Vault)
  ansible-vault view ~/ansible/vars/secret.yml

  # Editar el archivo cifrado (pedira la clave de Vault)
  ansible-vault edit ~/ansible/vars/secret.yml

  
  

  #--------- 3) UI (crear playbook con nano) ----------
  sudo dnf -y install nano || true
  nano ~/ansible/playbooks/ui.yml
  # Copia y pega el siguiente contenido en nano y guarda:
  # --- INICIO ui.yml ---
- hosts: frontend
  become: true
  vars:
    repo_url: https://github.com/Kose117/devops-rampup.git
    app_dir: /opt/movie-analyst
    ui_dir: /opt/movie-analyst/movie-analyst-ui
    fe_port: "80"
    backend_origin: "http://${module.alb_internal.alb_dns_name}"
  tasks:

  - name: Ensure packages (reintentos)
    shell: |
      for i in $(seq 1 20); do dnf -y install nodejs git && exit 0 || sleep 15; done; exit 1

  - name: Crear carpeta base
    file:
      path: "{{ app_dir }}"
      state: directory
      mode: '0755'

  - name: Obtener repo
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


  # --- FIN ui.yml ---
  ansible-playbook -i ~/ansible/inventory/hosts ~/ansible/playbooks/ui.yml

  #--------- 4) API (crear playbook con nano) ----------
  nano ~/ansible/playbooks/api.yml
  # Copia y pega el siguiente contenido (usa Vault; no pegues la password en claro):
  # --- INICIO api.yml ---
- hosts: backend
  become: true
  vars_files:
    - /home/ec2-user/ansible/vars/secret.yml
  vars:
    repo_url: https://github.com/Kose117/devops-rampup.git
    app_dir: /opt/movie-analyst
    api_dir: /opt/movie-analyst/movie-analyst-api
    db_host: "${module.rds.endpoint}"
    db_user: "${var.db_username}"
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

  - name: Obtener repo
    git:
      repo: "{{ repo_url }}"
      dest: "{{ app_dir }}"
      version: HEAD
      force: yes

  - name: Instalar dependencias API (npm install)
    shell: npm install --production --no-audit --no-fund
    args:
      chdir: "{{ api_dir }}"

  - name: Cargar schema en RDS (idempotente)
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

      
  # --- FIN api.yml ---
  # Ejecutar solicitando la contraseña de Vault
  ansible-playbook --ask-vault-pass -i ~/ansible/inventory/hosts ~/ansible/playbooks/api.yml
  
  

  #--------- 5) Verificaciones ----------
  curl -i http://${module.alb_public.alb_dns_name}/
  # Ejecutar desde el bastion o una instancia privada
  curl -i http://${module.alb_internal.alb_dns_name}/api/health
  curl -i http://${module.alb_internal.alb_dns_name}/api/movies

  #--------- 6) SSH y Logs ----------
  # Bastion
  ssh -i "${module.ssh_key.private_key_path}" ec2-user@${module.bastion.public_ip}

  # Conectar al frontend (desde el bastion)
  ssh ec2-user@${module.frontend.private_ip}
  # Ver estado del servicio
  sudo systemctl status movie-analyst-ui --no-pager
  # Ver logs
  sudo journalctl -u movie-analyst-ui -n 50 --no-pager
  # Probar localmente
  curl -i http://localhost/

  # Conectar a cada backend (desde el bastion)
  ${join("\n  ", [for ip in module.backend.private_ips : "ssh ec2-user@${ip}"])}
  # Ver estado del servicio (en cada backend)
  sudo systemctl status movie-analyst-api --no-pager
  # Ver logs (en cada backend)
  sudo journalctl -u movie-analyst-api -n 50 --no-pager
  # Probar localmente (en cada backend)
  curl -i http://localhost/api/health
  EOT
  description = "Guia de despliegue fusionada: resumen + comandos con separadores (#---------) y edicion via nano"
}
