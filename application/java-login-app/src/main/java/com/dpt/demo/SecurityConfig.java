package com.dpt.demo;

import jakarta.servlet.DispatcherType;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.dao.EmptyResultDataAccessException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.core.userdetails.User;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;

@Configuration
@EnableWebSecurity
public class SecurityConfig {

    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http)
            throws Exception {

        http
            .authorizeHttpRequests(auth -> auth
                .dispatcherTypeMatchers(
                    DispatcherType.FORWARD,
                    DispatcherType.ERROR
                ).permitAll()
                .requestMatchers(
                    "/", "/home", "/login",
                    "/register", "/error"
                ).permitAll()
                .anyRequest().authenticated()
            )
            .formLogin(form -> form
                .loginPage("/login")
                .loginProcessingUrl("/login")
                .usernameParameter("userName")
                .passwordParameter("password")
                .defaultSuccessUrl("/user", true)
                .failureUrl("/login?error")
                .permitAll()
            )
            .logout(logout -> logout
                .logoutSuccessUrl("/login?logout")
                .permitAll()
            );

        return http.build();
    }

    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }

    @Bean
    public UserDetailsService databaseUsers(JdbcTemplate jdbc) {
        return new UserDetailsService() {
            @Override
            public UserDetails loadUserByUsername(String username) {
                try {
                    return jdbc.queryForObject(
                        "SELECT username, password FROM Employee WHERE username = ?",
                        (rs, rowNum) -> User
                            .withUsername(rs.getString("username"))
                            .password(rs.getString("password"))
                            .roles("USER")
                            .build(),
                        username
                    );
                } catch (EmptyResultDataAccessException ex) {
                    throw new UsernameNotFoundException("Invalid credentials");
                }
            }
        };
    }
}
