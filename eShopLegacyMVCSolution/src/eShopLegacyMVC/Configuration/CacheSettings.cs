namespace eShopLegacyMVC.Configuration
{
    /// <summary>
    /// Configuration settings for distributed cache
    /// </summary>
    public class CacheSettings
    {
        /// <summary>
        /// Whether to use Redis cache instead of in-memory cache
        /// </summary>
        public bool UseRedis { get; set; } = false;

        /// <summary>
        /// Redis instance name for cache operations
        /// </summary>
        public string InstanceName { get; set; } = "eShopLegacyMVC";

        /// <summary>
        /// Default session timeout in minutes
        /// </summary>
        public int SessionTimeoutMinutes { get; set; } = 30;
    }
}