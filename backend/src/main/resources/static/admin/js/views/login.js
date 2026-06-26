/**ChronoFlow Admin — Login View*/
(function () {
  'use strict';

  window.LoginView = {
    render: function () {
      var html = ''
        + '<div class="login-wrapper">'
        + '  <div class="login-card">'
        + '    <h1 class="login-title">时纪流</h1>'
        + '    <p class="login-subtitle">管理后台</p>'
        + '    <form id="login-form">'
        + '      <div class="form-group">'
        + '        <label>用户名</label>'
        + '        <input class="form-input" type="text" id="login-username" placeholder="请输入用户名" autocomplete="username" autofocus>'
        + '      </div>'
        + '      <div class="form-group">'
        + '        <label>密码</label>'
        + '        <input class="form-input" type="password" id="login-password" placeholder="请输入密码" autocomplete="current-password">'
        + '      </div>'
        + '      <div class="form-group">'
        + '        <div class="error-msg" id="login-error"></div>'
        + '      </div>'
        + '      <button type="submit" class="btn btn-primary" id="login-btn">登 录</button>'
        + '    </form>'
        + '  </div>'
        + '</div>';

      document.getElementById('view-container').innerHTML = html;

      var form = document.getElementById('login-form');
      var btn = document.getElementById('login-btn');
      var errorEl = document.getElementById('login-error');

      form.addEventListener('submit', function (e) {
        e.preventDefault();

        var username = document.getElementById('login-username').value.trim();
        var password = document.getElementById('login-password').value;

        if (!username || !password) {
          errorEl.textContent = '请输入用户名和密码';
          return;
        }

        btn.disabled = true;
        btn.textContent = '登录中...';
        errorEl.textContent = '';

        API.login(username, password).then(function (data) {
          if (!data.data || data.data.role !== 'ADMIN') {
            if (data.role === 'ADMIN') {
              API.saveLogin(data);
              window.location.hash = '#/feedbacks';
              return;
            }
            throw new Error('您没有管理员权限');
          }
          API.saveLogin(data.data);
          window.location.hash = '#/feedbacks';
        }).catch(function (err) {
          errorEl.textContent = err.message || '登录失败，请检查用户名和密码';
        }).finally(function () {
          btn.disabled = false;
          btn.textContent = '登 录';
        });
      });
    },
  };
})();