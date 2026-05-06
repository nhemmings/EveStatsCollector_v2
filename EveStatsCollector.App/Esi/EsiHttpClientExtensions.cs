namespace EveStatsCollector.Esi;

using System.Net;
using Microsoft.Extensions.Http.Resilience;
using Polly;

internal static class EsiHttpClientExtensions
{
    public static IHttpClientBuilder AddEsiResilience(this IHttpClientBuilder builder)
    {
        // Polly retry — outer layer; retries pass through EsiRateLimitHandler on each attempt
        builder.AddResilienceHandler("EsiRetry", pipeline =>
        {
            pipeline.AddRetry(new HttpRetryStrategyOptions
            {
                MaxRetryAttempts = 3,
                BackoffType      = DelayBackoffType.Exponential,
                UseJitter        = true,
                ShouldHandle     = new PredicateBuilder<HttpResponseMessage>()
                    .Handle<HttpRequestException>()
                    .HandleResult(r => (int)r.StatusCode >= 500)
                    .HandleResult(r => r.StatusCode == HttpStatusCode.TooManyRequests) // 429
                    .HandleResult(r => (int)r.StatusCode == 420),                      // error limit
                DelayGenerator = static args =>
                {
                    var status = (int?)args.Outcome.Result?.StatusCode;

                    if (status == 429)
                    {
                        var retryAfter = args.Outcome.Result!.Headers.RetryAfter?.Delta;
                        if (retryAfter.HasValue)
                            return new ValueTask<TimeSpan?>(retryAfter.Value);
                    }

                    if (status == 420)
                    {
                        if (args.Outcome.Result!.Headers.TryGetValues(
                                "X-ESI-Error-Limit-Reset", out var vals)
                            && int.TryParse(vals.FirstOrDefault(), out var secs))
                            return new ValueTask<TimeSpan?>(TimeSpan.FromSeconds(secs));
                    }

                    return new ValueTask<TimeSpan?>((TimeSpan?)null); // default exponential + jitter
                },
            });
        });

        // Rate limit tracker — inner layer; updates state on every attempt including retries
        builder.AddHttpMessageHandler<EsiRateLimitHandler>();

        return builder;
    }
}
