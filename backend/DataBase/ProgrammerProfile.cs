namespace DataBase
{
    public class ProgrammerProfile
    {
        public int Id { get; set; }

        public int UserId { get; set; }

        public string Nickname { get; set; }

        public string PhoneNumber { get; set; }

        public string Country { get; set; }

        public string City { get; set; }

        public string Specialty { get; set; }

        public string University { get; set; }

        public byte[]? Certificate { get; set; }

        public string? CertificateType { get; set; }

        public string? CertificateName { get; set; }

        public byte[]? CV { get; set; }

        public string? CVName { get; set; }

        public string? LinkedInUrl { get; set; }

        public int Rating { get; set; } = 0;

        public bool IsVerified { get; set; } = false;

        public byte[]? ProfileImage { get; set; }

        public string? ImageContentType { get; set; }

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        public DateTime? UpdatedAt { get; set; }

        public User User { get; set; }
    }
}