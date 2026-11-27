package com.dpt.demo;

import org.junit.jupiter.api.Test;
import org.springframework.dao.EmptyResultDataAccessException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.authentication.dao.DaoAuthenticationProvider;
import org.springframework.security.core.userdetails.User;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

class SecurityConfigTest {

    @Test
    void authenticationUsesGenericErrorForUnknownUserAndWrongPassword() {

        JdbcTemplate jdbc = mock(JdbcTemplate.class);
        PasswordEncoder encoder = new BCryptPasswordEncoder();

        String storedHash = encoder.encode("CorrectPassword123!");

        when(jdbc.queryForObject(
            anyString(),
            org.mockito.ArgumentMatchers.<RowMapper<UserDetails>>any(),
            anyString()
        )).thenAnswer(invocation -> {
            String username = invocation.getArgument(2);

            if (!"adalace".equals(username)) {
                throw new EmptyResultDataAccessException(1);
            }

            return User.withUsername("adalace")
                .password(storedHash)
                .roles("USER")
                .build();
        });

        DaoAuthenticationProvider provider =
            new DaoAuthenticationProvider(
                new SecurityConfig().databaseUsers(jdbc)
            );

        provider.setPasswordEncoder(encoder);

        assertTrue(provider.isHideUserNotFoundExceptions());

        BadCredentialsException wrongPassword = assertThrows(
            BadCredentialsException.class,
            () -> provider.authenticate(
                new UsernamePasswordAuthenticationToken(
                    "adalace", "WrongPassword123!"
                )
            )
        );

        BadCredentialsException unknownUser = assertThrows(
            BadCredentialsException.class,
            () -> provider.authenticate(
                new UsernamePasswordAuthenticationToken(
                    "nonexistentuser", "WrongPassword123!"
                )
            )
        );

        assertEquals(wrongPassword.getMessage(), unknownUser.getMessage());

        assertTrue(provider.authenticate(
            new UsernamePasswordAuthenticationToken(
                "adalace", "CorrectPassword123!"
            )
        ).isAuthenticated());
    }
}
