class Validators {
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Введите email';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Введите корректный email';
    }
    return null;
  }

  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Введите пароль';
    }
    if (value.length < 6) {
      return 'Пароль должен содержать минимум 6 символов';
    }
    return null;
  }

  // Добавлен недостающий метод
  static String? validateConfirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) {
      return 'Подтвердите пароль';
    }
    if (value != password) {
      return 'Пароли не совпадают';
    }
    return null;
  }

  static String? validateUsername(String? value) {
      if (value == null || value.isEmpty) {
        return 'Введите имя пользователя';
      }
      if (value.length < 3) {
        return 'Имя пользователя должно содержать минимум 3 символа';
      }
      if (value.length > 30) {
        return 'Имя пользователя слишком длинное';
      }
      // Только буквы, цифры и underscore
      final usernameRegex = RegExp(r'^[a-zA-Z0-9_]+$');
      if (!usernameRegex.hasMatch(value)) {
        return 'Только буквы, цифры и _';
      }
      return null;
    }


  static String? validateTaskTitle(String? value) {
    if (value == null || value.isEmpty) {
      return 'Введите название задачи';
    }
    if (value.length < 3) {
      return 'Название должно содержать минимум 3 символа';
    }
    return null;
  }

  static String? validateName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Введите имя';
    }
    if (value.length < 2) {
      return 'Имя должно содержать минимум 2 символа';
    }
    return null;
  }
}
