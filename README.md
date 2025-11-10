# monolith-to-microservices-transformation

This GitHub repository is a hands-on demonstration project inspired by the Technical Needs outlined for a Principal Architect role. It simulates the unraveling of a monolithic .NET application (e.g., a simple SaaS inventory management system) into a distributed microservices architecture. The goal is to showcase key skills like architectural transformation, cloud-native deployment on Azure with Kubernetes, observability, CI/CD, and integrations.

The repo is structured to guide you through the "North Star" roadmap: from monolith baseline to a highly available, multi-region microservices setup with disaster recovery. It's built with .NET 8, SQL Server, Kafka for messaging, and Databricks for data lakehouse. Java alternatives are noted for adaptability.

## Repo Structure
```
monolith-to-microservices-transformation/
├── README.md                  # This file: Overview, setup, and roadmap
├── docs/                      # Documentation
│   ├── north-star-architecture.md  # Target state diagram (PlantUML)
│   ├── roadmap.md             # Phased execution plan
│   └── integrations-guide.md  # 3rd-party setup (ERP, HRIS mocks)
├── monolith/                  # Starting point: Legacy monolithic app
│   ├── InventoryApp.sln
│   ├── Controllers/           # ASP.NET MVC controllers
│   ├── Models/                # Entity models
│   ├── Services/              # Business logic (tightly coupled)
│   ├── Program.cs             # Entry point with SQL Server config
│   └── appsettings.json       # Monolith config
├── microservices/             # Transformed services
│   ├── inventory-service/     # Bounded context: Inventory microservice
│   │   ├── InventoryService.csproj
│   │   ├── Controllers/       # Web APIs
│   │   ├── Services/          # Decoupled logic
│   │   ├── Program.cs         # .NET minimal API with API Gateway prep
│   │   └── Dockerfile         # Containerization
│   ├── order-service/         # Bounded context: Orders (with Kafka events)
│   │   ├── OrderService.csproj
│   │   ├── EventHandlers/     # Kafka consumer
│   │   └── Dockerfile
│   └── user-service/          # Bounded context: Users (with HRIS integration)
│       ├── UserService.csproj
│       ├── Integrations/      # Mock HRIS API calls
│       └── Dockerfile
├── infrastructure/            # IaC and cloud setup
│   ├── kubernetes/            # K8s manifests for multi-region HA
│   │   ├── deployments.yaml   # Microservices deployments
│   │   ├── services.yaml      # Load balancers
│   │   ├── ingress.yaml       # API Gateway (NGINX Ingress)
│   │   └── disaster-recovery.yaml  # Velero backups
│   ├── terraform/             # Azure automation
│   │   ├── main.tf            # AKS cluster, Event Hubs, SQL Managed Instance
│   │   ├── variables.tf       # Multi-region vars (East US, West Europe)
│   │   └── outputs.tf         # Outputs for certs/keys
│   └── bicep/                 # Alternative Azure IaC for serverless functions
│       └── main.bicep         # Azure Functions for event-driven workflows
├── observability/             # Monitoring and logging
│   ├── prometheus-config.yaml # Metrics collection
│   ├── grafana-dashboards/    # JSON dashboards for New Relic-like views
│   ├── logging/               # ELK stack setup
│   │   └── logstash.conf      # Log parsing for traces
│   └── cert-manager/          # Cert management with cert-manager K8s
├── ci-cd/                     # Pipelines
│   ├── teamcity/              # TeamCity build configs (XML)
│   │   └── build-steps.xml    # Build, test, deploy stages
│   ├── github-actions/        # Alternative: .github/workflows/deploy.yml
│   └── tests/                 # Unit/integration tests
│       ├── Inventory.Tests/   # xUnit tests with Moq
│       └── IntegrationTests/  # With TestContainers for SQL/Kafka
├── data/                      # Lakehouse demo
│   ├── databricks-notebook/   # Delta Lake ETL (Python/Scala)
│   └── snowflake-scripts/     # Alternative SQL warehouse setup
├── .gitignore                 # Standard .NET + Docker ignores
├── LICENSE                    # MIT
└── CONTRIBUTING.md            # How to extend for scale (10+ yrs exp sim)
```

## Quick Setup & Run
1. **Prerequisites**: .NET 8 SDK, Docker, kubectl, Terraform, Azure CLI (free tier ok), Git.
2. Clone: `git clone https://github.com/kdahal/monolith-to-microservices-transformation.git`
3. Monolith baseline: `cd monolith && dotnet run` (runs on localhost:5000, connects to local SQL Server).
4. Deploy microservices:
   - `cd infrastructure/terraform && terraform init && terraform apply` (deploys AKS, Event Hubs).
   - `cd microservices && docker-compose up` (local dev; swap to K8s for prod).
5. Observability: `kubectl apply -f observability/` then access Grafana at port 3000.
6. CI/CD: Trigger TeamCity pipeline or GitHub Actions on push.
7. Test scale: Load test with JMeter (scripts in `/tests`), simulate 3rd-party integrations (mock ERP via Postman collections in `/docs`).

## Key Demos Aligned to Technical Needs
- **Architectural Transformation**: Start with `/monolith` (tight-coupled SaaS app). Migrate to `/microservices` with bounded contexts (e.g., inventory as macro-service). See `/docs/north-star-architecture.md` for UML: monolith → event-sourced micros via Kafka.
- **Core Tech**: .NET C# Web APIs in services; SQL Server in Terraform (migrate to Cosmos DB for HA).
- **Distributed Systems & Cloud**: Kubernetes manifests for AKS multi-region; serverless Azure Functions in `/infrastructure/bicep`; Kafka (Event Hubs) for orders; Databricks notebook for lakehouse analytics on inventory data.
- **Observability**: ELK for logs/traces; Prometheus/Grafana for metrics (integrates Application Insights); certs via cert-manager.
- **Tools & Scale**: Git branches for roadmap phases; xUnit tests; JIRA-like issues in CONTRIBUTING.md; mocks for ERP/HRIS/Ad exchanges in `/microservices/user-service/Integrations`. Simulates 10+ yrs enterprise SaaS with cloud migration history.

Sure, let's add a "Local Setup" section to your README.md—it's a great idea to make the repo self-contained for anyone who clones it. Here's the text you can copy-paste right into your README (I kept it simple, with steps for monolith and microservices, including the tests we did). I put it after the "Overview" or "Project Structure" section if you have one.

### Local Setup

This project demonstrates a monolith app unraveling into microservices with .NET 8, EF Core, Docker, and SQL. Here's how to get it running locally.

#### Prerequisites
- .NET 8 SDK (download from [dotnet.microsoft.com](https://dotnet.microsoft.com)).
- Docker Desktop (for containers and SQL).
- EF Core tools: `dotnet tool install --global dotnet-ef --version 8.0.8`.

#### 1. Start SQL and Microservices (Docker)
From the root:
```bash
cd microservices
docker-compose up -d  # Starts SQL, inventory, order, user services (~2 min first time)
docker-compose ps  # Check all "Up"?
docker logs microservices-sql-server-1 | tail -5  # "SQL Server is now ready"?
```

#### 2. Run Migrations
```bash
# Monolith
cd ../../monolith/InventoryApp
dotnet ef migrations add InitialCreate --startup-project .
dotnet ef database update --startup-project .

# Inventory-Service
cd ../../microservices/inventory-service
dotnet ef migrations add InitialCreate --startup-project .
dotnet ef database update --startup-project .
cd ..
```

#### 3. Run Monolith
```bash
cd ../../monolith/InventoryApp
dotnet run
```
- Browser: http://localhost:5264/Inventory
- Add item (Name: "Test", Quantity: 5, Price: 5.99)—submit, refresh (persists?).
- Ctrl+C to stop, rerun `dotnet run`, refresh—still there? (DB win!)

#### 4. Test Microservices
```bash
cd ../../microservices
# Inventory (5001)
curl http://localhost:5001/inventory  # []

curl -X POST http://localhost:5001/inventory -H "Content-Type: application/json" -d '{"name":"Micro Test","quantity":5,"price":4.99}'  # Creates item

curl http://localhost:5001/inventory  # Shows item

# Persistence
docker-compose restart inventory-service
sleep 5
curl http://localhost:5001/inventory  # Still shows?

# Other Services
curl -X POST http://localhost:5002/orders -H "Content-Type: application/json" -d '{"itemName":"Test Order","quantity":3}'  # Order event

curl http://localhost:5003/users/1  # Mock user
```

#### Troubleshooting
- Conn errors: Check SA_PASSWORD in docker-compose.yml matches appsettings.json.
- 500 on /inventory: Check logs `docker-compose logs inventory-service`.
- Swagger: http://localhost:5001/swagger (interactive test).

#### Stop
```bash
docker-compose down  # Stops containers
```

Ready for cloud? See "Deployment" section for Terraform/AKS.

---

This repo is executable and extensible—fork it to practice leading a real transformation! PRs welcome for Java ports or AWS swaps. Questions? Open an issue.

*Stars and forks appreciated to track community transformations! 🌟*
