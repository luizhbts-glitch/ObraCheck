# Referência da API — L7 Build Manager (Requisições, Cotações e Ordens de Compra)

> **Aviso importante**: isso foi levantado por engenharia reversa (leitura do bundle JS
> minificado do próprio app + observação do tráfego de rede), não é documentação oficial
> da L7. Os endpoints podem mudar sem aviso. Antes de construir uma integração de produção
> em cima disso, vale confirmar com a L7 se existe uma API oficial/suportada para
> integrações externas, com autenticação própria (client/API key) — o esquema de
> autenticação atual (abaixo) é o mesmo usado pelo app web para o usuário logado, não é
> pensado pra uso servidor-a-servidor.

## Ambiente

- Base URL: `https://build-manager-api-snriv.ondigitalocean.app/api/v1`
- Todas as respostas em JSON.

## Autenticação

- Header: `Authorization: Bearer <JWT>`
- O JWT contém `{ tenant, iat, exp, sub }` (`sub` = id do usuário). Validade observada: 24h (`exp - iat = 86400`).
- O token é obtido via login (`POST /login`, não capturamos o payload) e renovado via `POST /refresh?user=true`, chamado automaticamente pelo app a cada carregamento.
- Não existe (que tenhamos encontrado) um fluxo de autenticação separado para clientes/integrações — é o mesmo token de sessão do usuário logado no navegador.

## Catálogos auxiliares (usados pelos 3 recursos abaixo)

| Recurso | Endpoint | Retorna |
|---|---|---|
| Obras | `GET /buildings` | `{results:[{id, name, address:{...}, ...}]}` |
| Categorias | `GET /categories?order={"name":"ASC"}` | `{id, name, productIds:[...]}` — categoria já vem com a lista de produtos dela |
| Centros de custo | `GET /costcenters?buildingId={id}` | `{id, buildingId, item, name, description, canHaveCosts, value, building:{...}}` |
| Produtos (catálogo completo) | `GET /products?index=true&order={"name":"ASC"}` | array direto (sem paginação nesse modo): `{id, controlId, categoryId, name, description, unit, averageReferencePrice, lastPurchaseDate}` |

## 1. Requisições (`purchaserequests`)

| Ação | Endpoint |
|---|---|
| Listar | `GET /purchaserequests?page=1&pageSize=100&status[]=quoting&baseStatus[]=closed&expand[]=items&expand[]=items.product&expand[]=creator&expand[]=updater&expand[]=approver&expand[]=costCenter&expand[]=costCenter.building&index=true` |
| Detalhe | `GET /purchaserequests/{id}?expand[]=items&expand[]=items.product&expand[]=costCenter&expand[]=costCenter.building` |
| Criar | `POST /purchaserequests` (JSON puro) |
| Atualizar | `PUT /purchaserequests/{id}` |
| Excluir | `DELETE /purchaserequests/{id}` |

**Valores possíveis de filtro:**
- `status[]`: `quoting`, `approved`, `purchased`, `rejected` (e outros não observados)
- `baseStatus[]`: `created`, `rejected`, `closed`

**Payload de criação:**
```json
{
  "baseStatus": "created",
  "costCenterId": 172,
  "referenceCategoryId": 1,
  "observation": "opcional — omitir o campo se vazio, não mandar null",
  "items": [
    { "productId": 112, "quantity": 1, "complement": "opcional — omitir se vazio" }
  ]
}
```

**Formato de retorno (GET com expand completo):**
```json
{
  "id": 985,
  "baseStatus": "created",
  "status": "quoting",
  "costCenterId": 171,
  "referenceCategoryId": 54,
  "buildingName": "Arsen Sabiá",
  "referenceCategoryName": "Material Elétrico",
  "purchaseOrderIds": [59],
  "createdBy": 24, "createdAt": "...", "updatedBy": 24, "updatedAt": "...",
  "approvedBy": null, "approvedAt": null,
  "items": [
    { "id": 3454, "purchaseRequestId": 985, "productId": 1247, "complement": null, "quantity": 12,
      "product": { "id": 1247, "categoryId": 54, "name": "...", "description": "...", "unit": "UN" } }
  ],
  "creator": { "id": 24, "username": "...", "email": "...", "firstName": "...", "lastName": "..." },
  "costCenter": { "id": 171, "buildingId": 117, "item": "1.7", "name": "...", "building": {...} }
}
```

Observação importante: **`purchaseOrderIds`** é o campo que liga a requisição à(s) ordem(ns) de compra. Na grande maioria dos casos tem só 1 elemento; em raríssimos casos (split de fornecedor) pode ter mais de um — nesse caso não há, no corpo da requisição, informação de qual item foi pra qual OC (seria preciso cruzar por `productId` com os itens de cada OC individualmente).

## 2. Cotações (`quotations`)

| Ação | Endpoint |
|---|---|
| Listar | `GET /quotations?page=1&pageSize=100&index=true` |
| Detalhe | `GET /quotations/{id}` |
| Criar | `POST /quotations` |
| Atualizar | `PUT /quotations/{id}` |
| Aprovar | `PATCH /quotations/{id}/approve` |
| Mudar status | `PATCH /quotations/{id}/status` |
| Adicionar fornecedor à cotação | `POST /quotations/{id}/requests` |
| Remover fornecedor da cotação | `DELETE /quotations/{id}/requests/{supplierRequestId}` |
| Adicionar item | `POST /quotations/{id}/items` |
| Excluir | `DELETE /quotations/{id}` |

**Campo-chave**: `purchaseRequestId` — liga a cotação de volta à requisição de origem. Uma requisição pode ter mais de uma cotação ao longo do tempo (recotação); nesse caso a mais recente (`createdAt` maior) é a válida/atual.

**Formato de retorno:**
```json
{
  "id": 75, "purchaseRequestId": 110, "costCenterId": 142,
  "buildingName": "Bit 580", "costCenterName": "1.4 - Infra estrutura",
  "referenceCategoryName": "Materiais Básicos",
  "baseStatus": "closed", "status": "closed",
  "createdBy": 4, "createdAt": "...", "updatedBy": 4, "updatedAt": "...",
  "approvedBy": 7, "approvedAt": "..."
}
```

Rotas de tela (front-end) equivalentes, úteis pra montar links diretos: `/cotacoes/{id}/mapa` (visualizar), `/cotacoes/precadastro?purchaseRequestId={id}` (criar a partir de uma requisição).

## 3. Ordens de Compra (`purchaseorders`)

| Ação | Endpoint |
|---|---|
| Listar | `GET /purchaseorders?page=1&pageSize=100&index=true` |
| Detalhe | `GET /purchaseorders/{id}` |
| Processo/histórico | `GET /purchaseorders/{id}/process` |
| Criar | `POST /purchaseorders` |
| Atualizar | `PUT /purchaseorders/{id}` |
| Finalizar (mudar status) | `PATCH /purchaseorders/{id}/status` |
| Aprovar | `PATCH /purchaseorders/{id}/approve` |
| Excluir | `DELETE /purchaseorders/{id}` |
| Relatório | `GET /purchaseorders/report` |

**Formato de retorno (listagem):**
```json
{
  "id": 59, "idempotencyKey": "...",
  "supplierId": 47, "supplierName": "Bell Aço",
  "billingConditionId": 30, "costCenterId": 142, "billingCompanyId": 12, "addressId": 22,
  "shipping": 0, "discount": 0,
  "baseStatus": "closed", "status": "closed",
  "createdBy": 10, "createdAt": "...", "updatedBy": 3, "updatedAt": "...",
  "approvedBy": 3, "approvedAt": "...",
  "buildingName": "Bit 580",
  "subTotal": 850000, "total": 850000, "postingsTotal": 850000, "balance": 0,
  "address": { "id": 22, "street": "...", "city": "...", "state": "..." }
}
```

Valores monetários (`subTotal`, `total`, etc.) parecem estar em **centavos** (ex: `850000` = R$ 8.500,00) — vale confirmar com o programador/L7.

Rota de tela equivalente: `/ordemdecompra/{id}` (o número exibido "OC nº X" na tela é o próprio `id`).

Não encontramos, no objeto da ordem de compra, um campo que aponte de volta para a(s) requisição(ões) de origem — a ligação existe apenas no sentido requisição → `purchaseOrderIds` → OC.

## Resumo do fluxo de negócio observado

```
Requisição (purchaserequests)
  status: created → quoting → approved/purchased → (baseStatus: closed = finalizado)
      │
      ├─→ Cotação (quotations, via purchaseRequestId)
      │
      └─→ Ordem de Compra (purchaseorders, referenciada em purchaserequest.purchaseOrderIds)
```

---
*Documento gerado a partir de engenharia reversa em 2026-07-23 — sujeito a mudanças no sistema da L7.*
