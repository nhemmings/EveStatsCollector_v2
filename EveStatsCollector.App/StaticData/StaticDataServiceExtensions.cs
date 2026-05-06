namespace EveStatsCollector.StaticData;

internal static class StaticDataServiceExtensions
{
    public static IServiceCollection AddStaticData(this IServiceCollection services)
    {
        services.AddSingleton<StaticDataBuildChecker>();
        services.AddSingleton<StaticDataDownloader>();
        services.AddSingleton<StaticDataRepository>();
        services.AddSingleton<StaticDataImporter>();
        return services;
    }
}
