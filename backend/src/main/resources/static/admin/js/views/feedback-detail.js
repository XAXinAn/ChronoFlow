/**ChronoFlow Admin — Feedback Detail View*/
(function () {
  'use strict';

  var STATUSES = { pending: '待处理', processing: '处理中', resolved: '已解决', closed: '已关闭' };
  var STATUS_CLASSES = { pending: 'badge-pending', processing: 'badge-processing', resolved: 'badge-resolved', closed: 'badge-closed' };
  var STATUS_LIST = ['pending', 'processing', 'resolved', 'closed'];
  var TYPES = { bug: '问题反馈', suggestion: '功能建议', other: '其他' };
  var TYPE_CLASSES = { bug: 'badge-bug', suggestion: 'badge-suggestion', other: 'badge-other' };

  var state = {
    feedback: null,
    loading: true,
    error: null,
    replyText: '',
    isReplying: false,
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

  function render() {
    var main = document.getElementById('view-container');

    if (state.loading) {
      main.innerHTML = '<div class="loading"><div class="spinner"></div><p>加载中...</p></div>';
      return;
    }

    if (state.error) {
      main.innerHTML = ''
        + '<a class="back-link" onclick="window.history.back()">&#x2190; 返回列表</a>'
        + '<div class="state-box">'
        + '  <span class="state-icon">&#x26A0;</span>'
        + '  <p>' + escapeHTML(state.error) + '</p>'
        + '  <button class="btn btn-outline" onclick="window.FeedbackDetailView.loadDetail()">重新加载</button>'
        + '</div>';
      return;
    }

    var f = state.feedback;
    if (!f) return;

    var typeLabel = TYPES[f.type] || f.type;
    var typeClass = TYPE_CLASSES[f.type] || 'badge-other';
    var statusLabel = STATUSES[f.status] || f.status;
    var statusClass = STATUS_CLASSES[f.status] || 'badge-pending';

    var imagesHTML = '';
    if (f.imageUrls && f.imageUrls.length > 0) {
      imagesHTML = '<div class="images-row">'
        + f.imageUrls.map(function (url, i) {
            var fullUrl = url;
            if (fullUrl.indexOf('://') === -1) fullUrl = window.location.origin + (url.indexOf('/') === 0 ? '' : '/') + url;
            return '<a href="' + fullUrl + '" target="_blank"><img src="' + fullUrl + '" alt="图片' + (i + 1) + '"></a>';
          }).join('')
        + '</div>';
    }

    // Status chips
    var chipsHTML = '<div class="status-chips">'
      + STATUS_LIST.map(function (s) {
          var active = s === f.status ? ' active' : '';
          var label = STATUSES[s];
          return '<button class="chip' + active + '" onclick="window.FeedbackDetailView.changeStatus(\'' + s + '\')">' + label + '</button>';
        }).join('')
      + '</div>';

    // Reply form
    var replyFormHTML = ''
      + '<div class="reply-form">'
      + '  <textarea id="reply-input" placeholder="输入回复内容（最多1000字）" oninput="window.FeedbackDetailView.updateCharCount()">' + escapeHTML(state.replyText) + '</textarea>'
      + '  <div class="reply-form-footer">'
      + '    <span class="char-count" id="reply-char-count">' + state.replyText.length + '/1000</span>'
      + '    <button class="btn btn-primary" style="width:auto" id="reply-btn" onclick="window.FeedbackDetailView.submitReply()"' + (state.isReplying ? ' disabled' : '') + '>'
      +       (state.isReplying ? '发送中...' : '发送回复')
      + '    </button>'
      + '  </div>'
      + '</div>';

    // Existing reply
    var existingReplyHTML = '';
    if (f.adminReply) {
      existingReplyHTML = ''
        + '<div class="reply-display">'
        + '  <div class="reply-display-header">&#x1F464; 管理员回复</div>'
        + '  <div class="reply-display-text">' + escapeHTML(f.adminReply) + '</div>'
        + '  <div class="reply-display-time">' + formatTime(f.updatedAt) + '</div>'
        + '</div>';
    }

    main.innerHTML = ''
      + '<a class="back-link" onclick="window.history.back()">&#x2190; 返回列表</a>'
      + '<div class="page-header">'
      + '  <div style="display:flex;align-items:center;gap:10px;flex-wrap:wrap">'
      + '    <span class="badge ' + statusClass + '"><span class="badge-dot"></span>' + statusLabel + '</span>'
      + '    <span class="badge ' + typeClass + '">' + typeLabel + '</span>'
      + '    <span style="font-size:12px;color:var(--text-secondary)">用户#' + f.userId + '</span>'
      + '    <span style="font-size:12px;color:var(--text-disabled)">' + formatTime(f.createdAt) + '</span>'
      + '  </div>'
      + '</div>'
      + '<div class="card no-hover">'
      + '  <div style="font-size:14px;line-height:1.8;white-space:pre-wrap">' + escapeHTML(f.content) + '</div>'
      +    imagesHTML
      + '</div>'
      + '<div class="section-title">状态管理</div>'
      + chipsHTML
      + '<div class="section-title">' + (f.adminReply ? '编辑回复' : '回复反馈') + '</div>'
      + replyFormHTML
      + existingReplyHTML;
  }

  function loadDetail(id) {
    state.loading = true;
    state.error = null;
    state.feedback = null;
    state.replyText = '';
    render();

    API.getFeedbackDetail(id)
      .then(function (data) {
        state.feedback = data.data || data;
        state.loading = false;
        render();
      })
      .catch(function (err) {
        state.error = err.message || '加载失败';
        state.loading = false;
        render();
      });
  }

  function changeStatus(newStatus) {
    if (!state.feedback || state.feedback.status === newStatus) return;

    API.updateFeedbackStatus(state.feedback.id, newStatus)
      .then(function (data) {
        state.feedback = (data.data || data);
        Utils.showToast('状态已更新', 'success');
        render();
      })
      .catch(function (err) {
        Utils.showToast(err.message || '操作失败', 'error');
      });
  }

  function submitReply() {
    var textarea = document.getElementById('reply-input');
    var reply = textarea ? textarea.value.trim() : '';
    if (!reply) {
      Utils.showToast('请输入回复内容', 'error');
      return;
    }

    state.isReplying = true;
    render();

    API.replyToFeedback(state.feedback.id, reply)
      .then(function (data) {
        state.feedback = (data.data || data);
        state.replyText = '';
        state.isReplying = false;
        Utils.showToast('回复成功', 'success');
        render();
      })
      .catch(function (err) {
        state.isReplying = false;
        Utils.showToast(err.message || '回复失败', 'error');
        render();
      });
  }

  function updateCharCount() {
    var textarea = document.getElementById('reply-input');
    if (textarea) {
      state.replyText = textarea.value;
      var count = document.getElementById('reply-char-count');
      if (count) {
        count.textContent = textarea.value.length + '/1000';
        count.className = 'char-count' + (textarea.value.length > 1000 ? ' over' : '');
      }
    }
  }

  // Expose
  window.FeedbackDetailView = {
    render: function (id) { loadDetail(id); },
    loadDetail: function () { loadDetail(state.feedback ? state.feedback.id : null); },
    changeStatus: changeStatus,
    submitReply: submitReply,
    updateCharCount: updateCharCount,
  };

  function escapeHTML(str) {
    var div = document.createElement('div');
    div.appendChild(document.createTextNode(str));
    return div.innerHTML;
  }
})();