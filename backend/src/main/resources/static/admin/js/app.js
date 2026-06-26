/**ChronoFlow Admin — App Shell*/
(function () {
  'use strict';

  // ========== Utilities ==========
  window.Utils = {
    showToast: function (message, type) {
      var container = document.getElementById('toast-container');
      if (!container) {
        container = document.createElement('div');
        container.id = 'toast-container';
        container.className = 'toast-container';
        document.body.appendChild(container);
      }

      var toast = document.createElement('div');
      toast.className = 'toast' + (type ? ' ' + type : '');
      toast.textContent = message;
      container.appendChild(toast);

      setTimeout(function () {
        toast.style.opacity = '0';
        toast.style.transition = 'opacity 0.3s';
        setTimeout(function () {
          if (toast.parentNode) toast.parentNode.removeChild(toast);
        }, 300);
      }, 3000);
    },

    
    confirm: function (title, message, confirmText, isDangerous) {
      return new Promise(function (resolve) {
        var overlay = document.createElement('div');
        overlay.className = 'modal-overlay';
        overlay.innerHTML = ''
          + '<div class="modal-box">'
          + '  <h3 class="modal-title">' + escapeHTML(title) + '</h3>'
          + '  <p class="modal-message">' + escapeHTML(message) + '</p>'
          + '  <div class="modal-actions">'
          + '    <button class="btn btn-outline" id="modal-cancel">取消</button>'
          + '    <button class="btn btn-primary' + (isDangerous ? ' btn-danger' : '') + '" id="modal-confirm" style="width:auto">' + escapeHTML(confirmText) + '</button>'
          + '  </div>'
          + '</div>';

        document.body.appendChild(overlay);

        function cleanup() {
          if (overlay.parentNode) overlay.parentNode.removeChild(overlay);
        }

        overlay.querySelector('#modal-cancel').onclick = function () { cleanup(); resolve(false); };
        overlay.querySelector('#modal-confirm').onclick = function () { cleanup(); resolve(true); };
        overlay.addEventListener('click', function (e) {
          if (e.target === overlay) { cleanup(); resolve(false); }
        });
      });
    },
  };

  // ========== Router ==========
  var SIDEBAR_ROUTES = ['feedbacks', 'users'];
  var prevRoute = null;

  function getRoute() {
    var hash = window.location.hash || '#/';
    return hash.substring(1); // remove #
  }

  function parseRoute() {
    var path = getRoute();
    var parts = path.split('/').filter(Boolean);

    var route = {
      path: path,
      name: parts[0] || '',
      params: parts.slice(1),
    };

    // Default redirect
    if (!route.name) {
      if (API.isLoggedIn() && API.isAdmin()) {
        route = { path: '/feedbacks', name: 'feedbacks', params: [] };
      } else {
        route = { path: '/login', name: 'login', params: [] };
      }
    }

    return route;
  }

  function navigate(hash) {
    window.location.hash = '#' + hash;
  }

  function updateSidebar(routeName) {
    var sidebar = document.getElementById('sidebar');
    var main = document.getElementById('main-content');

    if (routeName === 'login') {
      if (sidebar) sidebar.classList.add('hidden');
      if (main) main.classList.add('full-width');
    } else {
      if (sidebar) sidebar.classList.remove('hidden');
      if (main) main.classList.remove('full-width');

      // Highlight active nav
      var items = document.querySelectorAll('.nav-item');
      items.forEach(function (item) {
        item.classList.remove('active');
        if (item.getAttribute('data-route') === routeName) {
          item.classList.add('active');
        }
      });
    }
  }

  function renderRoute() {
    var route = parseRoute();

    // Auth guard for non-login routes
    if (route.name !== 'login') {
      if (!API.isLoggedIn()) {
        window.location.hash = '#/login';
        return;
      }
      if (!API.isAdmin()) {
        // Logged in but not admin
        document.getElementById('view-container').innerHTML = ''
          + '<div class="state-box">'
          + '  <span class="state-icon">&#x1F6AB;</span>'
          + '  <p>您没有管理员权限</p>'
          + '  <button class="btn btn-outline" onclick="API.logout()">返回登录</button>'
          + '</div>';
        updateSidebar('login');
        return;
      }
    } else {
      // If already logged in as admin, redirect to feedbacks
      if (API.isLoggedIn() && API.isAdmin()) {
        window.location.hash = '#/feedbacks';
        return;
      }
    }

    updateSidebar(route.name);
    prevRoute = route.name + '/' + route.params.join('/');

    // Dispatch to view
    switch (route.name) {
      case 'login':
        LoginView.render();
        break;
      case 'feedbacks':
        if (route.params.length > 0) {
          FeedbackDetailView.render(route.params[0]);
        } else {
          FeedbacksView.render();
        }
        break;
      case 'users':
        UsersView.render();
        break;
      default:
        window.location.hash = '#/feedbacks';
    }
  }

  // ========== Init ==========
  function init() {
    // Wire logout button
    var logoutBtn = document.getElementById('logout-btn');
    if (logoutBtn) {
      logoutBtn.addEventListener('click', function () {
        API.logout();
      });
    }

    // Listen for hash changes
    window.addEventListener('hashchange', renderRoute);

    // Initial render
    renderRoute();
  }

  // Expose
  window.App = { navigate: navigate, getRoute: getRoute };

  // Run on DOM ready
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();

function escapeHTML(str) {
  if (!str) return '';
  var div = document.createElement('div');
  div.appendChild(document.createTextNode(str));
  return div.innerHTML;
}