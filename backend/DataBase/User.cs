using DataBase.Models;

namespace DataBase
{
    public class User
    {
        public int Id { get; set; }

        public string Email { get; set; }

        public string PasswordHash { get; set; }

        public string UserType { get; set; }

        // ===== Navigation =====
        public CustomerProfile? CustomerProfile { get; set; }

        public ProgrammerProfile? ProgrammerProfile { get; set; }

        // ===== Social Feature =====
        public ICollection<Post> Posts { get; set; } = new List<Post>();
        public ICollection<PostLike> Likes { get; set; } = new List<PostLike>();
        public ICollection<PostComment> Comments { get; set; } = new List<PostComment>();
    }
}