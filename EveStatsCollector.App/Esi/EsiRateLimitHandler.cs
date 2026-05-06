namespace EveStatsCollector.Esi;

using System.Collections.Concurrent;
using System.Net.Http.Headers;

internal sealed class EsiRateLimitHandler(ILogger<EsiRateLimitHandler> logger) : DelegatingHandler
{
    private const int LowWaterWarning  = 20;
    private const int LowWaterThrottle = 5;

    private readonly ConcurrentDictionary<string, int> _groupRemaining =
        new(StringComparer.OrdinalIgnoreCase);

    private volatile int _errorLimitRemain = 100;

    protected override async Task<HttpResponseMessage> SendAsync(
        HttpRequestMessage request, CancellationToken ct)
    {
        var response = await base.SendAsync(request, ct);
        await ObserveAndThrottleAsync(response, ct);
        return response;
    }

    private async Task ObserveAndThrottleAsync(HttpResponseMessage response, CancellationToken ct)
    {
        var group = GetHeader(response.Headers, "X-Ratelimit-Group") ?? "default";

        if (TryGetInt(response.Headers, "X-Ratelimit-Remaining", out var remaining))
        {
            _groupRemaining[group] = remaining;

            if (remaining <= LowWaterWarning)
                logger.LogWarning(
                    "ESI rate limit low for group {Group}: {Remaining} tokens remaining",
                    group, remaining);

            if (remaining <= LowWaterThrottle)
            {
                logger.LogWarning(
                    "ESI rate limit critically low for group {Group} ({Remaining} remaining) — throttling",
                    group, remaining);
                await Task.Delay(TimeSpan.FromSeconds(2), ct);
            }
        }

        if (TryGetInt(response.Headers, "X-ESI-Error-Limit-Remain", out var errRemain))
        {
            _errorLimitRemain = errRemain;

            if (errRemain <= LowWaterWarning)
                logger.LogWarning(
                    "ESI error limit low: {ErrorsRemaining} errors remaining in current window",
                    errRemain);
        }
    }

    private static string? GetHeader(HttpResponseHeaders headers, string name) =>
        headers.TryGetValues(name, out var vals) ? vals.FirstOrDefault() : null;

    private static bool TryGetInt(HttpResponseHeaders headers, string name, out int value)
    {
        value = 0;
        return headers.TryGetValues(name, out var vals)
            && int.TryParse(vals.FirstOrDefault(), out value);
    }
}
