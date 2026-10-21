using MailKit.Net.Smtp;
using MailKit.Security;
using MimeKit;

namespace Services
{
    public class EmailService
    {
        private readonly string _smtpServer = "smtp.gmail.com";
        private readonly int _port = 587;
        private readonly string _senderEmail = "devlinksystem3@gmail.com";
        private readonly string _password = "opcf lzxp btcs kjql";

        public bool SendEmail(
            string toEmail,
            string subject,
            string body,
            string senderName = "DevLink")
        {
            try
            {
                var message = new MimeMessage();

                message.From.Add(
                    new MailboxAddress(senderName, _senderEmail));

                message.To.Add(
                    new MailboxAddress("", toEmail));

                message.Subject = subject;

                message.Body = new TextPart("plain")
                {
                    Text = body
                };

                using (var client = new SmtpClient())
                {
                    client.Connect(
                        _smtpServer,
                        _port,
                        SecureSocketOptions.StartTls);

                    client.Authenticate(
                        _senderEmail,
                        _password);

                    client.Send(message);

                    client.Disconnect(true);
                }

                return true;
            }
            catch (Exception ex)
            {
                Console.WriteLine(
                    $"Email error: {ex.Message}");

                return false;
            }
        }
        public async Task<bool> SendEmailAsync(string toEmail, string subject, string body, string senderName = "DevLink")
{
    return await Task.Run(() => SendEmail(toEmail, subject, body, senderName));
}
    }
    
}