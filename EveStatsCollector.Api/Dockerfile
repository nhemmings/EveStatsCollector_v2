FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src
COPY EveStatsCollector.Api/ EveStatsCollector.Api/
RUN dotnet restore EveStatsCollector.Api/EveStatsCollector.Api.csproj
RUN dotnet publish EveStatsCollector.Api/EveStatsCollector.Api.csproj \
    -c Release -o /app/publish

FROM mcr.microsoft.com/dotnet/aspnet:10.0
WORKDIR /app
COPY --from=build /app/publish .
ENTRYPOINT ["dotnet", "EveStatsCollector.Api.dll"]
