# Movie Analyst - Infraestructura AWS

## Descripción
Infraestructura como código para la aplicación Movie Analyst en AWS usando Terraform.

## Arquitectura
- **VPC**: 2 subnets públicas + 2 privadas en 2 AZs
- **Frontend**: EC2 en subnet privada con Nginx
- **Backend**: EC2 en subnet privada con Node.js/Express
- **Database**: RDS MySQL en subnet privada
- **Load Balancer**: ALB público
- **NAT**: Instancia EC2 como NAT (ahorro de costos vs NAT Gateway)
- **Bastion**: Jump server para acceso SSH
- **Monitoring**: CloudWatch dashboards y alarmas

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