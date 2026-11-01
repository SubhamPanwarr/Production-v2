package com.dpt.demo;

import java.nio.charset.StandardCharsets;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.servlet.ModelAndView;

@Controller
public class register {
    private final JdbcTemplate jdbc;
    private final PasswordEncoder passwordEncoder;

    public register(JdbcTemplate jdbc, PasswordEncoder passwordEncoder) {
        this.jdbc = jdbc;
        this.passwordEncoder = passwordEncoder;
    }

    @GetMapping("/register")
    public String registerPage() {
        return "register";
    }

    @PostMapping("/register")
    public ModelAndView submit(
            @RequestParam String firstName,
            @RequestParam String lastName,
            @RequestParam String email,
            @RequestParam String userName,
            @RequestParam String password) {
        if (firstName == null || firstName.isBlank() || firstName.length() > 100 ||
            lastName == null || lastName.isBlank() || lastName.length() > 100 ||
            email == null || email.length() > 254 ||
            !email.matches("^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$") ||
            userName == null || !userName.matches("[A-Za-z0-9_.-]{3,40}") ||
            password == null || password.length() < 12 ||
            password.getBytes(StandardCharsets.UTF_8).length > 72) {
            return new ModelAndView("register", "message", "Invalid input. Use a 3-40 character username and a password of 12-72 bytes.");
        }
        String hash = passwordEncoder.encode(password);
        try {
            jdbc.update(
                "INSERT INTO Employee (first_name,last_name,email,username,password,regdate) " +
                "VALUES (?,?,?,?,?,CURRENT_TIMESTAMP)",
                firstName, lastName, email, userName, hash
            );
            return new ModelAndView("redirect:/login?registered");
        } catch (DuplicateKeyException e) {
            return new ModelAndView("register", "message", "Username or email is already registered.");
        }
    }
}
