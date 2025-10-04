using Microsoft.Extensions.Logging;
using System;
using System.Diagnostics;
using System.Reflection;
using System.Web;

namespace eShopLegacyMVC
{
    public class MvcApplication : HttpApplication
    {
        private readonly ILogger<MvcApplication> _logger;

        public MvcApplication()
        {
            // Note: In a real scenario, you might want to use a different logging approach for Global.asax
            // since dependency injection is not readily available here. This is mainly kept for compatibility.
        }

        protected void Application_Start()
        {
            // This method is kept for compatibility with System Web Adapters
            // Most functionality has been moved to Program.cs
        }

        /// <summary>
        /// Track the machine name and the start time for the session inside the current session
        /// </summary>
        protected void Session_Start(Object sender, EventArgs e)
        {
            HttpContext.Current.Session["MachineName"] = Environment.MachineName;
            HttpContext.Current.Session["SessionStartTime"] = DateTime.Now;
        }

        protected void Application_BeginRequest(object sender, EventArgs e)
        {
            // Note: This functionality has been moved to middleware in Program.cs
            // This method is kept for compatibility with System Web Adapters
            // Logging is now handled by the middleware pipeline
        }
    }

    public class ActivityIdHelper
    {
        public override string ToString()
        {
            if (Trace.CorrelationManager.ActivityId == Guid.Empty)
            {
                Trace.CorrelationManager.ActivityId = Guid.NewGuid();
            }

            return Trace.CorrelationManager.ActivityId.ToString();
        }
    }

    public class WebRequestInfo
    {
        public override string ToString()
        {
            return HttpContext.Current?.Request?.RawUrl + ", " + HttpContext.Current?.Request?.UserAgent;
        }
    }
}
