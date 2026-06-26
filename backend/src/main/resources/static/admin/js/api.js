/**ChronoFlow Admin — API Client*/
(function () {
  'use strict';

  var BASE = window.location.origin;
  var TOKEN_KEY = 'admin_token';

  // ========== Helpers ==========

  function getToken() {
    try {
      var data = JSON.parse(localStorage.getItem(TOKEN_KEY) || 'null');
      return data && data.accessToken ? data.accessToken : null;
    } catch (e) {
      return null;
    }
  }

  function getUserInfo() {
    try {
      return JSON.parse(localStorage.getItem(TOKEN_KEY) || 'null');
    } catch (e) {
      return null;
    }
  }

  function isLoggedIn() {
    return !!getToken();
  }

  function isAdmin() {
    var info = getUserInfo();
    return info && info.role === 'ADMIN';
  }

  function saveLogin(data) {
    localStorage.setItem(TOKEN_KEY, JSON.stringify(data));
  }

  function logout() {
    localStorage.removeItem(TOKEN_KEY);
    window.location.hash = '#/login';
  }

  function handleAuthError() {
    localStorage.removeItem(TOKEN_KEY);
    window.location.hash = '#/login';
  }

  // ========== HTTP ==========

  function request(method, path, params, body, skipAuth) {
    var url = BASE + path;
    if (params) {
      var qs = Object.keys(params)
        .filter(function (k) { return params[k] !== null && params[k] !== undefined && params[k] !== ''; })
        .map(function (k) { return encodeURIComponent(k) + '=' + encodeURIComponent(params[k]); })
        .join('&');
      if (qs) url += '?' + qs;
    }

    var headers = { 'Content-Type': 'application/json' };
    var token = getToken();
    if (token && !skipAuth) {
      headers['Authorization'] = 'Bearer ' + token;
    }

    var opts = {
      method: method,
      headers: headers,
    };
    if (body && method !== 'GET') {
      opts.body = JSON.stringify(body);
    }

    return fetch(url, opts).then(function (resp) {
      return resp.json().then(function (data) {
        if (resp.status === 401) {
          handleAuthError();
          throw new Error('登录已过期，请重新登录');
        }
        if (resp.status === 403) {
          throw new Error(data.message || '没有管理员权限');
        }
        if (!resp.ok) {
          throw new Error(data.message || '请求失败 (' + resp.status + ')');
        }
        return data;
      });
    }).catch(function (err) {
      if (err.name === 'TypeError' && err.message === 'Failed to fetch') {
        throw new Error('网络连接失败，请检查网络');
      }
      throw err;
    });
  }

  // ========== Public API ==========

  window.API = {
    getToken: getToken,
    getUserInfo: getUserInfo,
    isLoggedIn: isLoggedIn,
    isAdmin: isAdmin,
    saveLogin: saveLogin,
    logout: logout,

    // Auth
    login: function (username, password) {
      return request('POST', '/api/auth/login', null, {
        username: username,
        password: password,
      }, true); // skipAuth: no token needed for login
    },

    // Feedback management
    getFeedbacks: function (page, size, status, type) {
      return request('GET', '/api/admin/feedbacks', {
        page: page || 1,
        size: size || 20,
        status: status || null,
        type: type || null,
      });
    },

    getFeedbackDetail: function (id) {
      return request('GET', '/api/admin/feedbacks/' + id);
    },

    replyToFeedback: function (id, reply) {
      return request('POST', '/api/admin/feedbacks/' + id + '/reply', null, {
        reply: reply,
      });
    },

    updateFeedbackStatus: function (id, status) {
      return request('POST', '/api/admin/feedbacks/' + id + '/status', null, {
        status: status,
      });
    },

    // User management
    getUsers: function (page, size) {
      return request('GET', '/api/admin/users', {
        page: page || 1,
        size: size || 20,
      });
    },

    updateUserRole: function (id, role) {
      return request('POST', '/api/admin/users/' + id + '/role', null, {
        role: role,
      });
    },
  };
})();