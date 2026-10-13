namespace DataBase
{
    public class CustomerProfile
    {
        public int Id { get; set; }

        public int UserId { get; set; }

        public string Nickname { get; set; }

        public string Country { get; set; }

        public string City { get; set; }

        public string PhoneNumber { get; set; }

        public byte[]? ProfileImage { get; set; }

        public string? ImageContentType { get; set; }

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        public DateTime? UpdatedAt { get; set; }

        public User User { get; set; }
    }
}