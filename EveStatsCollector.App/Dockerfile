FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src
COPY EveStatsCollector.App/EveStatsCollector.csproj EveStatsCollector.App/
RUN dotnet restore EveStatsCollector.App/EveStatsCollector.csproj
RUN dotnet publish EveStatsCollector.App/EveStatsCollector.csproj \
    -c Release -o /app/publish

FROM mcr.microsoft.com/dotnet/runtime:10.0
WORKDIR /app
COPY --from=build /app/publish .
ENTRYPOINT ["dotnet", "EveStatsCollector.dll"]
