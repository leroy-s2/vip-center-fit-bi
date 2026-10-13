# Taste
- Writes and expects communication in Spanish. Confidence: 0.9
- Gives dense, multi-requirement prompts (mixes stack, scope, and business rules) and expects the agent to parse and structure all of it, not just the first item. Confidence: 0.6
- Wants a plan produced and the problem understood before any implementation ("primero armes el plan y entiendas su significancia"). Confidence: 0.85
- Uses a .NET / ASP.NET Core + SQL Server (Docker) + Power BI + JMeter stack for data/BI projects. Confidence: 0.6
- Wants APIs fully documented (per-consumer / per-actor), because they will build a frontend on top later. Confidence: 0.75
- Prefers incremental data processing over full reloads (ETL should process only new/changed data, never reload everything). Confidence: 0.6
- Models data warehouses as a single constellation of data marts sharing conformed dimensions. Confidence: 0.55
- Likes to study the data model one data mart at a time, not just the whole constellation: wants a separate Prisma schema per data mart (dim + that mart) and a per-datamart Mermaid ERD, viewed in the VS Code preview. Confidence: 0.6
- Separates environments explicitly: keeps dev tooling (npm/Prisma/UML, JMeter, dotnet seeder) on their local machine and only runs Docker/containers on the remote VM/host — expects the agent not to mix local-machine steps with server-side steps. Confidence: 0.6
