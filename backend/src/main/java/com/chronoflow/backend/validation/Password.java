package com.chronoflow.backend.validation;

import jakarta.validation.Constraint;
import jakarta.validation.Payload;
import java.lang.annotation.*;

@Documented
@Constraint(validatedBy = PasswordValidator.class)
@Target({ElementType.FIELD})
@Retention(RetentionPolicy.RUNTIME)
public @interface Password {
    String message() default "密码必须包含数字和英文";
    Class<?>[] groups() default {};
    Class<? extends Payload>[] payload() default {};
}
