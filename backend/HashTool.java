import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
public class HashTool { public static void main(String[] a) {
System.out.println(new BCryptPasswordEncoder().encode("admin123")); } }
