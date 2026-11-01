package com.dpt.demo;

import java.security.Principal;

import org.junit.jupiter.api.Test;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.web.servlet.ModelAndView;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

class WebControllersTest {

    private final JdbcTemplate jdbc = mock(JdbcTemplate.class);
    private final PasswordEncoder encoder = mock(PasswordEncoder.class);
    private final register registration = new register(jdbc, encoder);

    private static final String PASSWORD = "StrongPassword123!";

    @Test
    void registrationPageLoads() {
        assertEquals("register", registration.registerPage());
    }

    @Test
    void validRegistrationStoresHashedPassword() {
        when(encoder.encode(PASSWORD)).thenReturn("hashed-password");

        ModelAndView result = registration.submit(
            "Ada", "Lovelace", "ada@example.com",
            "adalace", PASSWORD
        );

        assertEquals("redirect:/login?registered", result.getViewName());

        verify(encoder).encode(PASSWORD);
        verify(jdbc).update(
            contains("INSERT INTO Employee"),
            eq("Ada"), eq("Lovelace"),
            eq("ada@example.com"), eq("adalace"),
            eq("hashed-password")
        );
    }

    @Test
    void invalidRegistrationIsRejected() {
        assertEquals("register", registration.submit(
            "", "Lovelace", "ada@example.com",
            "adalace", PASSWORD
        ).getViewName());

        assertEquals("register", registration.submit(
            "Ada", "", "ada@example.com",
            "adalace", PASSWORD
        ).getViewName());

        assertEquals("register", registration.submit(
            "Ada", "Lovelace", "invalid-email",
            "adalace", PASSWORD
        ).getViewName());

        assertEquals("register", registration.submit(
            "Ada", "Lovelace", "ada@example.com",
            "bad username", PASSWORD
        ).getViewName());

        assertEquals("register", registration.submit(
            "Ada", "Lovelace", "ada@example.com",
            "adalace", "short"
        ).getViewName());

        assertEquals("register", registration.submit(
            "Ada", "Lovelace", "ada@example.com",
            "adalace", "x".repeat(73)
        ).getViewName());

        verifyNoInteractions(jdbc, encoder);
    }

    @Test
    void duplicateRegistrationIsHandled() {
        when(encoder.encode(PASSWORD)).thenReturn("hashed-password");

        when(jdbc.update(
            anyString(), any(), any(), any(), any(), any()
        )).thenThrow(new DuplicateKeyException("duplicate"));

        ModelAndView result = registration.submit(
            "Ada", "Lovelace", "ada@example.com",
            "adalace", PASSWORD
        );

        assertEquals("register", result.getViewName());
        assertEquals(
            "Username or email is already registered.",
            result.getModel().get("message")
        );
    }

    @Test
    void loginPageDisplaysGenericError() {
        login controller = new login();

        ModelAndView result = controller.loginPage("true", null);

        assertEquals("login", result.getViewName());
        assertEquals(
            "Invalid username or password.",
            result.getModel().get("errorMessage")
        );
    }

    @Test
    void loginPageDisplaysRegistrationNotice() {
        login controller = new login();

        ModelAndView result = controller.loginPage(null, "true");

        assertEquals("login", result.getViewName());
        assertEquals(
            "Registration complete. Please log in.",
            result.getModel().get("noticeMessage")
        );
    }

    @Test
    void userPageDisplaysAuthenticatedUsername() {
        login controller = new login();
        Principal principal = () -> "adalace";

        ModelAndView result = controller.userPage(principal);

        assertEquals("user", result.getViewName());
        assertEquals("adalace", result.getModel().get("username"));
    }

    @Test
    void homeRoutesRenderHomePage() {
        HomeController controller = new HomeController();

        assertEquals("home", controller.home().getViewName());
        assertEquals("home", controller.Default().getViewName());
    }
}
