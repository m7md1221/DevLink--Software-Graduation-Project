using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Services;
using Services.Auth;

namespace Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class EngagementsController : ControllerBase
    {
        private readonly EngagementService _engagements;
        private readonly ICurrentUser _currentUser;

        public EngagementsController(EngagementService engagements, ICurrentUser currentUser)
        {
            _engagements = engagements;
            _currentUser = currentUser;
        }

        private int CallerId => _currentUser.UserId!.Value;

        private IActionResult Reply(EngagementOutcome outcome) => outcome.Result switch
        {
            EngagementResult.NotFound => NotFound(new { message = outcome.Message }),
            EngagementResult.Forbidden => AuthProblem.Forbidden(HttpContext, outcome.Message),
            EngagementResult.Invalid => BadRequest(new { message = outcome.Message }),
            EngagementResult.Conflict => Conflict(new { message = outcome.Message }),
            _ => Ok(outcome.Body ?? new { message = outcome.Message })
        };

        [HttpGet("mine")]
        [Authorize(Policy = AuthPolicies.MemberOnly)]
        public async Task<IActionResult> Mine() => Ok(new { engagements = await _engagements.Mine(CallerId) });

        // The two parties, and admins for reading.
        [HttpGet("{id}")]
        [Authorize(Policy = AuthPolicies.MemberOnly)]
        public async Task<IActionResult> Get(int id) => Reply(await _engagements.Get(id, CallerId, _currentUser.IsAdmin));

        [HttpPost("{id}/deliveries")]
        [Authorize(Policy = AuthPolicies.ProgrammerOnly)]
        public async Task<IActionResult> Deliver(int id, [FromBody] DeliveryInput input) =>
            Reply(await _engagements.Deliver(id, CallerId, input));

        [HttpPost("{id}/review")]
        [Authorize(Policy = AuthPolicies.CustomerOnly)]
        public async Task<IActionResult> Review(int id, [FromBody] ReviewInput input) =>
            Reply(await _engagements.Review(id, CallerId, input));

        [HttpPost("{id}/cancellation")]
        [Authorize(Policy = AuthPolicies.MemberOnly)]
        public async Task<IActionResult> RequestCancellation(int id, [FromBody] ReasonInput input) =>
            Reply(await _engagements.RequestCancellation(id, CallerId, input));

        [HttpPost("{id}/cancellation/agree")]
        [Authorize(Policy = AuthPolicies.MemberOnly)]
        public async Task<IActionResult> AgreeToCancellation(int id) =>
            Reply(await _engagements.AnswerCancellation(id, CallerId, agree: true));

        [HttpPost("{id}/cancellation/decline")]
        [Authorize(Policy = AuthPolicies.MemberOnly)]
        public async Task<IActionResult> DeclineCancellation(int id) =>
            Reply(await _engagements.AnswerCancellation(id, CallerId, agree: false));

        [HttpPost("{id}/admin-cancel")]
        [Authorize(Policy = AuthPolicies.AdminOnly)]
        public async Task<IActionResult> AdminCancel(int id, [FromBody] ReasonInput input) =>
            Reply(await _engagements.AdminCancel(id, CallerId, input));
    }
}
