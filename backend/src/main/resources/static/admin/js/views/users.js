/**ChronoFlow Admin — Users List View*/
(function () {
  'use strict';

  var state = {
    users: [],
    page: 1,
    size: 20,
    total: 0,
    loading: false,
    error: null,
  };

  function renderCards() {
    if (!state.users.length) {
      return ''
        + '<div class="state-box">'
        + '  <span class="state-icon">&#x1F465;</span>'
        + '  <p>暂无用户记录</p>'
        + '</div>';
    }

    return state.users.map(function (u) {
      var isAdmin = u.role === 'ADMIN';
      var isVerified = u.realNameVerified === true || u.realNameVerified === 'true' || u.realNameVerified === 1;

      var badgesHTML = '';
      if (isAdmin) badgesHTML += '<span class="badge badge-admin">管理员</span>';
      else badgesHTML += '<span class="badge badge-other">普通用户</span>';
      if (isVerified) badgesHTML += '<span class="badge badge-verified">已实名</span>';

      var actionBtn = isAdmin
        ? '<button class="btn btn-danger btn-sm" onclick="window.UsersView.demoteUser(' + u.id + ', \'' + escapeHTML(u.nickname || u.username) + '\')">降级</button>'
        : '<button class="btn btn-outline btn-sm" onclick="window.UsersView.promoteUser(' + u.id + ', \'' + escapeHTML(u.nickname || u.username) + '\')">提升</button>';

      return ''
        + '<div class="card no-hover">'
        + '  <div class="user-card">'
        + '    <div class="user-info">'
        + '      <span class="user-name">' + escapeHTML(u.nickname || '') + ' <span style="font-weight:400;color:var(--text-secondary);font-size:13px">@' + escapeHTML(u.username || '') + '</span></span>'
        + '      <span class="user-detail">ID: ' + u.id + ' | ' + escapeHTML(u.phone || '无手机号') + ' | ' + escapeHTML(u.email || '无邮箱') + '</span>'
        + '    </div>'
        + '    <div style="display:flex;align-items:center;gap:10px;flex-wrap:wrap">'
        + '      <div class="user-badges">' + badgesHTML + '</div>'
        + '      <div class="user-actions">' + actionBtn + '</div>'
        + '    </div>'
        + '  </div>'
        + '</div>';
    }).join('');
  }

  function renderPagination() {
    var totalPages = Math.ceil(state.total / state.size) || 1;
    return ''
      + '<div class="pagination">'
      + '  <button onclick="window.UsersView.loadPage(' + (state.page - 1) + ')"' + (state.page <= 1 ? ' disabled' : '') + '>上一页</button>'
      + '  <span>第 ' + state.page + ' 页，共 ' + state.total + ' 条</span>'
      + '  <button onclick="window.UsersView.loadPage(' + (state.page + 1) + ')"' + (state.page >= totalPages ? ' disabled' : '') + '>下一页</button>'
      + '</div>';
  }

  function renderLoading() {
    return '<div class="loading"><div class="spinner"></div><p>加载中...</p></div>';
  }

  function renderError(msg) {
    return ''
      + '<div class="state-box">'
      + '  <span class="state-icon">&#x26A0;</span>'
      + '  <p>' + escapeHTML(msg) + '</p>'
      + '  <button class="btn btn-outline" onclick="window.UsersView.loadData(true)">重新加载</button>'
      + '</div>';
  }

  function renderFull() {
    var main = document.getElementById('view-container');
    if (state.loading) {
      main.innerHTML = ''
        + '<div class="page-header"><h1 class="page-title">用户管理</h1></div>'
        + renderLoading();
      return;
    }

    if (state.error) {
      main.innerHTML = ''
        + '<div class="page-header"><h1 class="page-title">用户管理</h1></div>'
        + renderError(state.error);
      return;
    }

    main.innerHTML = ''
      + '<div class="page-header"><h1 class="page-title">用户管理</h1></div>'
      + renderCards()
      + renderPagination();
  }

  function loadData(refresh) {
    if (refresh) { state.page = 1; }
    state.loading = true;
    state.error = null;
    renderFull();

    API.getUsers(state.page, state.size)
      .then(function (data) {
        var d = data.data || data;
        state.users = d.records || [];
        state.total = d.total || 0;
        state.loading = false;
        renderFull();
      })
      .catch(function (err) {
        state.error = err.message || '加载失败';
        state.loading = false;
        renderFull();
      });
  }

  function loadPage(p) {
    var totalPages = Math.ceil(state.total / state.size) || 1;
    if (p < 1 || p > totalPages) return;
    state.page = p;
    loadData(false);
  }

  function promoteUser(id, name) {
    Utils.confirm('提升管理员', '确定要将 ' + name + ' 提升为管理员吗？', '确认提升', true)
      .then(function (confirmed) {
        if (!confirmed) return;
        return API.updateUserRole(id, 'ADMIN');
      })
      .then(function (data) {
        if (data) Utils.showToast('角色更新成功，用户需重新登录后生效', 'success');
        loadData(true);
      })
      .catch(function (err) {
        if (err) Utils.showToast(err.message || '操作失败', 'error');
      });
  }

  function demoteUser(id, name) {
    Utils.confirm('降级用户', '确定要将 ' + name + ' 降级为普通用户吗？', '确认降级', true)
      .then(function (confirmed) {
        if (!confirmed) return;
        return API.updateUserRole(id, 'USER');
      })
      .then(function (data) {
        if (data) Utils.showToast('角色更新成功，用户需重新登录后生效', 'success');
        loadData(true);
      })
      .catch(function (err) {
        if (err) Utils.showToast(err.message || '操作失败', 'error');
      });
  }

  // Expose
  window.UsersView = {
    render: function () { loadData(true); },
    loadData: loadData,
    loadPage: loadPage,
    promoteUser: promoteUser,
    demoteUser: demoteUser,
  };

  function escapeHTML(str) {
    if (!str) return '';
    var div = document.createElement('div');
    div.appendChild(document.createTextNode(str));
    return div.innerHTML;
  }
})();