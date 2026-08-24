# 11 — Banco de Dados: PostgreSQL no K8s vs Cloud SQL / RDS Gerenciado

> **Matriz de Decisão Arquitetural & FinOps:** Quando rodar o PostgreSQL dentro do próprio cluster K3s vs contratar instâncias gerenciadas (Google Cloud SQL / AWS RDS / Azure Database).

---

## 1. Comparativo Técnico e Financeiro

| Critério | PostgreSQL no K8s (StatefulSet + PVC) | Cloud SQL / AWS RDS Gerenciado |
| :--- | :--- | :--- |
| **Custo Adicional** | **US\$ 0** (Aproveita a CPU, RAM e SSD da VM já contratada) | **US\$ 25 a US\$ 75/mês** por ambiente |
| **Latência de Rede** | **Sub-milissegundo** (`postgres.namespace.svc:5432`) | 1 a 3ms (VPC Peering / Private Service Access) |
| **Isolamento de Falhas** | StatefulSet isolado por namespace (`dev` vs `prod`) | Instância física/virtual totalmente separada |
| **Backups** | Snapshot Diário de Disco GCP + `pg_dump` lógico agendado | Backups contínuos PITR (*Point-In-Time Recovery*) |
| **Consumo de Memória** | ~80 MB a 150 MB por instância (ideal em VMs de 8GB RAM) | 0 MB na VM da aplicação |
| **Recomendado para:** | **MVP, Startups, Homologação e Produção com FinOps otimizado** | **Grandes corporações com exigência estrita de auditoria/SLA** |

---

## 2. Padrão Recomendado de Persistência no K3s

Para garantir que nenhum dado seja perdido quando um pod reiniciar ou a VM for reiniciada:

1. **StorageClass `local-path` nativo do K3s**:
   - Os dados do Postgres são gravados fisicamente em `/var/lib/rancher/k3s/storage/` no disco permanente da VM.
2. **StatefulSet Declarativo**:
   ```yaml
   apiVersion: apps/v1
   kind: StatefulSet
   metadata:
     name: postgres
   spec:
     serviceName: postgres
     replicas: 1
     volumeClaimTemplates:
       - metadata:
           name: postgres-data
         spec:
           accessModes: ["ReadWriteOnce"]
           resources:
             requests:
               storage: 10Gi
   ```
3. **Strings de Conexão Limpas via DNS Interno**:
   - `postgresql://postgres:<SENHA>@postgres.eos-dev.svc.cluster.local:5432/eos_dev`

---

## 3. Os 3 Pilares Obrigatórios de Proteção do Banco na VM

1. **Volume Persistente K8s (PVC)**: Mantém os dados preservados entre reinicializações de Pods.
2. **Política Diária de Snapshot em Nuvem (GCP / AWS)**:
   - Política automática agendada (ex: 03:00 - 04:00 AM UTC).
   - Permite restaurar o servidor inteiro e todos os bancos em caso de desastre com 1 clique.
3. **Backup Lógico Agendado (`pg_dump` compactado)**:
   - Script [`scripts/10-backup-postgres-database.sh`](../scripts/10-backup-postgres-database.sh) com retenção de 15 dias.
