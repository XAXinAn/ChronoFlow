import 'package:flutter/material.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('隐私政策', style: TextStyle(fontWeight: FontWeight.w300)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '隐私政策',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '更新日期：2026年5月5日',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 24),
            const Text(
              '一、隐私政策导言',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '时纪流是一款简洁高效的个人日程管理应用。我们高度重视您的个人信息保护，本隐私政策旨在向您说明我们如何收集、使用、存储和保护您的个人信息。',
              style: TextStyle(fontSize: 14, color: Colors.black54, height: 1.6),
            ),
            const SizedBox(height: 16),
            const Text(
              '运营主体：舟山市时纪云人工智能应用软件有限责任公司',
              style: TextStyle(fontSize: 14, color: Colors.black54, height: 1.6),
            ),
            const SizedBox(height: 24),
            const Text(
              '二、我们如何收集和使用您的个人信息',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '1. 收集目的：我们收集您的个人信息以便为您提供日程管理、群组共享、拍照识别等服务。\n\n'
              '2. 收集信息类型：\n'
              '• 账户信息（用户名、手机号码）\n'
              '• 设备信息（设备型号、操作系统）\n'
              '• 日历信息（您创建的日程内容）\n'
              '• 位置信息（用于日程地点设置）\n'
              '• 相机权限（用于拍照识别日程）\n\n'
              '3. 个人信息存储：您的数据存储在中国大陆地区的服务器上，我们采用加密措施保护您的个人信息安全。\n\n'
              '4. 保留期限：您的个人信息将在您注销账户后15个工作日内删除。',
              style: TextStyle(fontSize: 14, color: Colors.black54, height: 1.6),
            ),
            const SizedBox(height: 24),
            const Text(
              '三、我们如何使用 Cookie 和同类技术',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '我们使用本地存储技术来保存您的偏好设置，如主题模式等。您可以通过设备设置管理相关权限。',
              style: TextStyle(fontSize: 14, color: Colors.black54, height: 1.6),
            ),
            const SizedBox(height: 24),
            const Text(
              '四、我们如何共享、转让您的个人信息',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '1. 群组共享：当您加入群组并分享日程时，您的日程信息将展示给群组成员。\n\n'
              '2. 第三方SDK：我们使用的第三方服务包括阿里云短信服务（用于验证码发送），该SDK可能收集必要的设备信息。\n\n'
              '3. 未经您的同意，我们不会将您的个人信息转让给任何第三方。',
              style: TextStyle(fontSize: 14, color: Colors.black54, height: 1.6),
            ),
            const SizedBox(height: 24),
            const Text(
              '五、我们如何保护您的信息',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '1. 数据加密：您的密码采用BCrypt加密存储。\n\n'
              '2. 传输安全：所有数据传输采用HTTPS加密。\n\n'
              '3. 访问审计：我们对用户数据的访问进行日志记录。\n\n'
              '4. 已取得的安全认证：遵循行业标准的安全规范。',
              style: TextStyle(fontSize: 14, color: Colors.black54, height: 1.6),
            ),
            const SizedBox(height: 24),
            const Text(
              '六、信息的存储',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '存储地点：中国大陆\n存储期限：自收集日期起5年内，或直到您注销账户',
              style: TextStyle(fontSize: 14, color: Colors.black54, height: 1.6),
            ),
            const SizedBox(height: 24),
            const Text(
              '七、您如何管理您的个人信息',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '1. 访问权：您可以在个人中心查看您的账户信息。\n\n'
              '2. 更正权：您可以修改您的昵称、手机号绑定。\n\n'
              '3. 删除权：您可以注销账户，我们将在15个工作日内删除您的数据。\n\n'
              '4. 撤回同意：您可以联系客服撤回同意。\n\n'
              '5. 注销方式：\n'
              '• APP内注销：我的 > 注销账号\n'
              '• 客服电话：18006569106\n'
              '• 电子邮件：3278904650@qq.com',
              style: TextStyle(fontSize: 14, color: Colors.black54, height: 1.6),
            ),
            const SizedBox(height: 24),
            const Text(
              '八、未成年人的保护',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '我们的应用主要面向成年人。如您的年龄分级为3+、8+、12+，请在监护人指导下使用。',
              style: TextStyle(fontSize: 14, color: Colors.black54, height: 1.6),
            ),
            const SizedBox(height: 24),
            const Text(
              '九、如何联系我们',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '如您对隐私政策有任何疑问，请联系我们：\n\n'
              '邮箱：3278904650@qq.com\n'
              '地址：浙江省舟山市定海区临城街道海大南路1号浙江海洋大学新城校区会展中心231-9室\n\n'
              '我们将在15个工作日内回复您的请求。',
              style: TextStyle(fontSize: 14, color: Colors.black54, height: 1.6),
            ),
            const SizedBox(height: 24),
            const Text(
              '十、隐私政策变更',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '如本隐私政策发生变更，我们将在APP内显著位置通知您。您继续使用我们的服务即表示您同意更新后的隐私政策。',
              style: TextStyle(fontSize: 14, color: Colors.black54, height: 1.6),
            ),
            const SizedBox(height: 32),
            Center(
              child: Text(
                '© 2026 时纪流 All Rights Reserved',
                style: TextStyle(fontSize: 12, color: Colors.black38),
              ),
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}