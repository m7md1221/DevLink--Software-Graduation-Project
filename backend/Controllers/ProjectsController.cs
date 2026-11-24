using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Services;
using Services.Auth;

namespace Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class ProjectsController : ControllerBase
    {
        private readonly ProjectService _projects;
        private readonly ICurrentUser _currentUser;

        public ProjectsController(ProjectService projects, ICurrentUser currentUser)
        {
            _projects = projects;
            _currentUser = currentUser;
        }

        private int CallerId => _currentUser.UserId!.Value;

        private IActionResult NotReady(ReadinessReport readiness) =>
            UnprocessableEntity(new { errorCode = "READINESS_BLOCKING_ISSUES", message = "The project isn't ready to submit yet.", readiness });

        private IActionResult Invalid(Dictionary<string, string> errors) =>
            BadRequest(new { message = "Some fields need attention.", errors });

        [HttpPost]
        [Authorize(Policy = AuthPolicies.CustomerOnly)]
        public async Task<IActionResult> Create([FromBody] ProjectInput input)
        {
            var (result, id, errors, readiness) = await _projects.Create(CallerId, input);
            return result switch
            {
                ProjectResult.Invalid => Invalid(errors!),
                ProjectResult.NotReady => NotReady(readiness!),
                _ => Ok(new { id, status = "Pending", message = "Your project was submitted and is waiting for review.", readiness })
            };
        }

        [HttpPut("{id}")]
        [Authorize(Policy = AuthPolicies.CustomerOnly)]
        public async Task<IActionResult> Update(int id, [FromBody] ProjectInput input)
        {
            var (result, errors, readiness) = await _projects.Update(id, CallerId, input);
            return result switch
            {
                ProjectResult.NotFound => NotFound(new { message = "Project not found" }),
                ProjectResult.Forbidden => AuthProblem.Forbidden(HttpContext, "Only the project owner can edit it."),
                ProjectResult.Locked => Conflict(new { message = "Only pending or rejected projects can be edited." }),
                ProjectResult.Invalid => Invalid(errors!),
                ProjectResult.NotReady => NotReady(readiness!),
                _ => Ok(new { id, status = "Pending", message = "Your changes were saved and the project is waiting for review.", readiness })
            };
        }

        // Lets the wizard show the readiness panel before anything is saved.
        [HttpPost("readiness")]
        [Authorize(Policy = AuthPolicies.CustomerOnly)]
        public IActionResult Readiness([FromBody] ProjectInput input) =>
            Ok(new { readiness = ProjectService.Readiness(input), errors = ProjectService.Validate(input) });

        [HttpGet("{id}/applicants")]
        [Authorize(Policy = AuthPolicies.CustomerOnly)]
        public async Task<IActionResult> Applicants(int id, [FromQuery] string? sort, [FromQuery] string? dir)
        {
            if (sort != null && !ProjectService.ApplicantSorts.Contains(sort.ToLowerInvariant()))
                return BadRequest(new { message = "Sort by submitted, coverage, amount, duration, rating or verified." });

            var (result, applicants) = await _projects.Applicants(id, CallerId, sort, dir);
            return result switch
            {
                ProjectResult.NotFound => NotFound(new { message = "Project not found" }),
                ProjectResult.Forbidden => AuthProblem.Forbidden(HttpContext, "Only the project owner can see its applicants."),
                _ => Ok(new { applicants })
            };
        }

        [HttpGet("{id}/applications/{applicationId}")]
        [Authorize(Policy = AuthPolicies.MemberOnly)]
        public async Task<IActionResult> Application(int id, int applicationId)
        {
            var (result, application) = await _projects.Application(id, applicationId, CallerId);
            return result switch
            {
                ProjectResult.NotFound => NotFound(new { message = "Application not found" }),
                ProjectResult.Forbidden => AuthProblem.Forbidden(HttpContext, "Only the project owner and the applicant can see this application."),
                _ => Ok(application)
            };
        }

        [HttpGet("applications/mine")]
        [Authorize(Policy = AuthPolicies.ProgrammerOnly)]
        public async Task<IActionResult> MyApplications() =>
            Ok(new { applications = await _projects.MyApplications(CallerId) });

        [HttpGet("{id}")]
        [Authorize(Policy = AuthPolicies.MemberOnly)]
        public async Task<IActionResult> Get(int id)
        {
            var (result, project) = await _projects.Details(id, CallerId, _currentUser.IsAdmin);
            return result == ProjectResult.Ok ? Ok(project) : NotFound(new { message = "Project not found" });
        }
    }
}
