package com.dpt.demo;

import java.security.Principal;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.servlet.ModelAndView;

@Controller
public class login {
    @GetMapping("/login")
    public ModelAndView loginPage(
            @RequestParam(value = "error", required = false) String error,
            @RequestParam(value = "registered", required = false) String registered) {
        ModelAndView page = new ModelAndView("login");
        if (error != null) page.addObject("errorMessage", "Invalid username or password.");
        if (registered != null) page.addObject("noticeMessage", "Registration request processed. If your account is available, please sign in.");
        return page;
    }

    // POST /login is processed by Spring Security, not this controller.
    @GetMapping("/user")
    public ModelAndView userPage(Principal principal) {
        return new ModelAndView("user", "username", principal.getName());
    }
}
