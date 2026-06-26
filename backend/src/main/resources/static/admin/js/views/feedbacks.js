/**ChronoFlow Admin — Feedbacks List View*/
(function () {
  'use strict';

  var TYPES = { bug: '问题反馈', suggestion: '功能建议', other: '其他' };
  var STATUSES = { pending: '待处理', processing: '处理中', resolved: '已解决', closed: '已关闭' };
  var TYPE_CLASSES = { bug: 'badge-bug', suggestion: 'badge-suggestion', other: 'badge-other' };
  var STATUS_CLASSES = { pending: 'badge-pending', processing: 'badge-processing', resolved: 'badge-resolved', closed: 'badge-closed' };

  var state = {
    feedbacks: [],
    page: 1,
    size: 20,
    total: 0,
    loading: false,
    error: null,
    filterStatus: '',
    filterType: '',
  };

  function formatTime(str) {
    if (!str) return '';
    var d = new Date(str);
    if (isNaN(d.getTime())) return str;
    return d.getFullYear() + '-' +
      String(d.getMonth() + 1).padStart(2, '0') + '-' +
      String(d.getDate()).padStart(2, '0') + ' ' +
      String(d.getHours()).padStart(2, '0') + ':' +
      String(d.getMinutes()).padStart(2, '0');
  }

  function renderFilters() {
    return ''
      + '<div class="filter-bar">'
      + '  <select class="filter-select" id="filter-status">'
      + '    <option value="">全部状态</option>'
      + '    <option value="pending"' + (state.filterStatus === 'pending' ? ' selected' : '') + '>待处理</option>'
      + '    <option value="processing"' + (state.filterStatus === 'processing' ? ' selected' : '') + '>处理中</option>'
      + '    <option value="resolved"' + (state.filterStatus === 'resolved' ? ' selected' : '') + '>已解决</option>'
      + '    <option value="closed"' + (state.filterStatus === 'closed' ? ' selected' : '') + '>已关闭</option>'
      + '  </select>'
      + '  <select class="filter-select" id="filter-type">'
      + '    <option value="">全部类型</option>'
      + '    <option value="bug"' + (state.filterType === 'bug' ? ' selected' : '') + '>问题反馈</option>'
      + '    <option value="suggestion"' + (state.filterType === 'suggestion' ? ' selected' : '') + '>功能建议</option>'
      + '    <option value="other"' + (state.filterType === 'other' ? ' selected' : '') + '>其他</option>'
      + '  </select>'
      + '</div>';
  }

  function renderCards() {
    if (!state.feedbacks.length) {
      return ''
        + '<div class="state-box">'
        + '  <span class="state-icon">&#x1F4ED;</span>'
        + '  <p>暂无反馈记录</p>'
        + '</div>';
    }

    return state.feedbacks.map(function (f) {
      var typeLabel = TYPES[f.type] || f.type;
      var statusLabel = STATUSES[f.status] || f.status;
      var typeClass = TYPE_CLASSES[f.type] || 'badge-other';
      var statusClass = STATUS_CLASSES[f.status] || 'badge-pending';
      var content = f.content.length > 80 ? f.content.substring(0, 80) + '...' : f.content;
      var hasImages = f.imageUrls && f.imageUrls.length > 0;

      return ''
        + '<div class="card" data-id="' + f.id + '" onclick="window.FeedbacksView.goDetail(' + f.id + ')">'
        + '  <div class="card-row">'
        + '    <span class="card-id">#' + f.id + '</span>'
        + '    <span class="card-id">用户' + f.userId + '</span>'
        + '    <span class="badge ' + typeClass + '">' + typeLabel + '</span>'
        + '    <span class="badge ' + statusClass + '">' + statusLabel + '</span>'
        + '  </div>'
        + '  <div class="card-content">' + escapeHTML(content) + '</div>'
        + '  <div class="card-meta">'
        + '    <span>' + formatTime(f.createdAt) + '</span>'
        + (hasImages ? '<span class="image-indicator">&#x1F5BC; ' + f.imageUrls.length + ' 张图片</span>' : '')
        + '  </div>'
        + '</div>';
    }).join('');
  }

  function renderPagination() {
    var totalPages = Math.ceil(state.total / state.size) || 1;
    return ''
      + '<div class="pagination">'
      + '  <button onclick="window.FeedbacksView.loadPage(' + (state.page - 1) + ')"' + (state.page <= 1 ? ' disabled' : '') + '>上一页</button>'
      + '  <span>第 ' + state.page + ' 页，共 ' + state.total + ' 条</span>'
      + '  <button onclick="window.FeedbacksView.loadPage(' + (state.page + 1) + ')"' + (state.page >= totalPages ? ' disabled' : '') + '>下一页</button>'
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
      + '  <button class="btn btn-outline" onclick="window.FeedbacksView.loadData(true)">重新加载</button>'
      + '</div>';
  }

  function renderFull() {
    var main = document.getElementById('view-container');
    if (state.loading) {
      main.innerHTML = ''
        + '<div class="page-header"><h1 class="page-title">反馈管理</h1></div>'
        + renderFilters()
        + renderLoading();
      return;
    }

    if (state.error) {
      main.innerHTML = ''
        + '<div class="page-header"><h1 class="page-title">反馈管理</h1></div>'
        + renderFilters()
        + renderError(state.error);
      return;
    }

    main.innerHTML = ''
      + '<div class="page-header"><h1 class="page-title">反馈管理</h1></div>'
      + renderFilters()
      + renderCards()
      + renderPagination();

    // Bind filter change events
    var statusSelect = document.getElementById('filter-status');
    var typeSelect = document.getElementById('filter-type');
    if (statusSelect) {
      statusSelect.addEventListener('change', function () {
        state.filterStatus = statusSelect.value;
        state.page = 1;
        loadData(true);
      });
    }
    if (typeSelect) {
      typeSelect.addEventListener('change', function () {
        state.filterType = typeSelect.value;
        state.page = 1;
        loadData(true);
      });
    }
  }

  function loadData(refresh) {
    if (refresh) { state.page = 1; }
    state.loading = true;
    state.error = null;
    renderFull();

    API.getFeedbacks(state.page, state.size, state.filterStatus || null, state.filterType || null)
      .then(function (data) {
        var d = data.data || data;
        state.feedbacks = d.records || [];
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

  function goDetail(id) {
    window.location.hash = '#/feedbacks/' + id;
  }

  function loadPage(p) {
    var totalPages = Math.ceil(state.total / state.size) || 1;
    if (p < 1 || p > totalPages) return;
    state.page = p;
    loadData(false);
  }

  // Expose
  window.FeedbacksView = {
    render: function () {
      loadData(true);
    },
    loadData: loadData,
    loadPage: loadPage,
    goDetail: goDetail,
  };

  // Utility
  function escapeHTML(str) {
    var div = document.createElement('div');
    div.appendChild(document.createTextNode(str));
    return div.innerHTML;
  }
})();