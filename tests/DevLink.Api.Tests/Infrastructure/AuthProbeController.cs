using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace DevLink.Api.Tests.Infrastructure
{
    // Test-only endpoints, added to the API through an application part in the test hosts.
    // M2.2 protects no real endpoint, so token validation is exercised here.
    [ApiController]
    [Route("__tests/auth")]
    public class AuthProbeController : ControllerBase
    {
        [HttpGet("me")]
        [Authorize]
        public IActionResult Me() => Ok(new
        {
            name = User.Identity?.Name,
            claims = User.Claims.ToDictionary(c => c.Type, c => c.Value)
        });

        [HttpGet("admin")]
        [Authorize(Roles = "Admin")]
        public IActionResult AdminOnly() => Ok();

        // Deliberately no attribute: proves the fail-closed default (T-7D-11). Excluded from the reflection test, which scans the API assembly only.
        [HttpGet("no-attribute")]
        public IActionResult NoAttribute() => Ok();

        [HttpGet("ping")]
        [AllowAnonymous]
        public IActionResult Ping() => Ok(new { ok = true });

        // An unhandled exception carrying text that must never reach the client.
        [HttpGet("boom")]
        [AllowAnonymous]
        public IActionResult Boom() => throw new InvalidOperationException("Simulated failure: SELECT secret FROM somewhere");
    }
}
