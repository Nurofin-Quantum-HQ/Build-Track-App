import re
import os

log_text = '''
lib/screen/projects/project_detail.dart:1600:44:
Context: The invocation of 'primary' is not allowed
in a constant expression.
                          color: AppColors.primary,
                                          ^
lib/screen/projects/project_detail.dart:1792:17:
Error: Constant evaluation error:
          const Icon(
                ^
lib/screen/projects/project_detail.dart:1794:30:
Context: The invocation of 'primary' is not allowed
in a constant expression.
            color: AppColors.primary,
                             ^
lib/screen/projects/project_detail.dart:1908:34:
Error: Constant evaluation error:
                    style: const TextStyle(
                                 ^
lib/screen/projects/project_detail.dart:1911:40:
Context: The invocation of 'primary' is not allowed
in a constant expression.
                      color: AppColors.primary,
                                       ^
lib/screen/projects/project_detail.dart:1928:32:
Error: Constant evaluation error:
                  child: const Icon(
                               ^
lib/screen/projects/project_detail.dart:1930:38:
Context: The invocation of 'primary' is not allowed
in a constant expression.
                    color: AppColors.primary,
                                     ^
lib/screen/projects/project_detail.dart:2000:32:
Error: Constant evaluation error:
                  child: const Icon(
                               ^
lib/screen/projects/project_detail.dart:2002:38:
Context: The invocation of 'primary' is not allowed
in a constant expression.
                    color: AppColors.primary,
                                     ^
lib/screen/projects/project_detail.dart:2055:38:
Error: Constant evaluation error:
                        style: const TextStyle(
                                     ^
lib/screen/projects/project_detail.dart:2056:44:
Context: The invocation of 'primary' is not allowed
in a constant expression.
                          color: AppColors.primary,
                                          ^
lib/screen/projects/project_detail.dart:2329:40:
Error: Constant evaluation error:
                          style: const TextStyle(
                                       ^
lib/screen/projects/project_detail.dart:2332:46:
Context: The invocation of 'primary' is not allowed
in a constant expression.
                            color:
                            AppColors.primary,
                                          ^
lib/screen/projects/project_detail.dart:2538:32:
Error: Constant evaluation error:
                  child: const Icon(
                               ^
lib/screen/projects/project_detail.dart:2540:38:
Context: The invocation of 'primary' is not allowed
in a constant expression.
                    color: AppColors.primary,
                                     ^
lib/screen/projects/project_detail.dart:2857:36:
Error: Constant evaluation error:
          builder: (lCtx) => const Center(
                                   ^
lib/screen/projects/project_detail.dart:2858:63:
Context: The invocation of 'primary' is not allowed
in a constant expression.
            child: CircularProgressIndicator(color:
            AppColors.primary),
                                          ^
lib/screen/projects/project_detail.dart:3126:35:
Error: Constant evaluation error:
                      icon: const Icon(
                                  ^
lib/screen/projects/project_detail.dart:3128:42:
Context: The invocation of 'primary' is not allowed
in a constant expression.
                        color: AppColors.primary,
                                         ^
lib/screen/projects/projectscreen.dart:143:15:
Error: Constant evaluation error:
        const TooltipActionButton(
              ^
lib/screen/projects/projectscreen.dart:145:38:
Context: The invocation of 'primary' is not allowed
in a constant expression.
          backgroundColor: AppColors.primary, 
                                     ^
lib/screen/projects/projectscreen.dart:249:40:
Error: Constant evaluation error:
                          child: const Icon(
                                       ^
lib/screen/projects/projectscreen.dart:251:46:
Context: The invocation of 'primary' is not allowed
in a constant expression.
                            color:
                            AppColors.primary,
                                          ^
lib/screen/projects/projectscreen.dart:277:36:
Error: Constant evaluation error:
                      child: const Icon(
                                   ^
lib/screen/projects/projectscreen.dart:279:42:
Context: The invocation of 'primary' is not allowed
in a constant expression.
                        color: AppColors.primary,
                                         ^
lib/screen/projects/projectscreen.dart:301:20:
Error: Constant evaluation error:
      return const Center(
                   ^
lib/screen/projects/projectscreen.dart:302:59:
Context: The invocation of 'primary' is not allowed
in a constant expression.
        child: CircularProgressIndicator(color:
        AppColors.primary),
                                          ^
lib/screen/reports/report.dart:41:19: Error:
Constant evaluation error:
            const TooltipActionButton(
                  ^
lib/screen/reports/report.dart:43:42: Context: The
invocation of 'primary' is not allowed in a constant
expression.
              backgroundColor: AppColors.primary,
                                         ^
lib/screen/reports/report.dart:372:31: Error:
Constant evaluation error:
                        const Text(
                              ^
lib/screen/reports/report.dart:377:46: Context: The
invocation of 'primary' is not allowed in a constant
expression.
                            color:
                            AppColors.primary,
                                          ^
lib/screen/reports/report.dart:1022:33: Error:
Constant evaluation error:
                    side: const BorderSide(
                                ^
lib/screen/reports/report.dart:1023:40: Context: The
invocation of 'primary' is not allowed in a constant
expression.
                      color: AppColors.primary,
                                       ^
lib/screen/reports/report.dart:1049:33: Error:
Constant evaluation error:
                    side: const BorderSide(
                                ^
lib/screen/reports/report.dart:1050:40: Context: The
invocation of 'primary' is not allowed in a constant
expression.
                      color: AppColors.primary,
                                       ^
lib/screen/reports/report.dart:1750:63: Error:
Constant evaluation error:
                                          children:
                                          const [
                                          ^
lib/screen/reports/report.dart:1755:71: Context: The
invocation of 'primary' is not allowed in a constant
expression.
                                          AppColors.
                                          primary,
                                          ^
lib/screen/reports/report.dart:1806:65: Error:
Constant evaluation error:
                                          children:
                                          const [
                                          ^
lib/screen/reports/report.dart:1811:73: Context: The
invocation of 'primary' is not allowed in a constant
expression.
                                          AppColors.
                                          primary,
                                          ^
lib/screen/reports/report.dart:1822:65: Error:
Constant evaluation error:
                                          children:
                                          const [
                                          ^
lib/screen/reports/report.dart:1827:73: Context: The
invocation of 'primary' is not allowed in a constant
expression.
                                          AppColors.
                                          primary,
                                          ^
lib/screen/reports/report.dart:1862:63: Error:
Constant evaluation error:
                                          children:
                                          const [
                                          ^
lib/screen/reports/report.dart:1867:71: Context: The
invocation of 'primary' is not allowed in a constant
expression.
                                          AppColors.
                                          primary,
                                          ^
lib/screen/reports/report.dart:1895:59: Error:
Constant evaluation error:
                                          icon:
                                          const
                                          Icon(
                                          ^
lib/screen/reports/report.dart:1897:66: Context: The
invocation of 'primary' is not allowed in a constant
expression.
                                          color:
                                          AppColors.
                                          primary,
                                          ^
lib/screen/reports/report.dart:2650:21: Error:
Constant evaluation error:
          children: const [
                    ^
lib/screen/reports/report.dart:2651:62: Context: The
invocation of 'primary' is not allowed in a constant
expression.
            Icon(Icons.edit_note, size: 16, color:
            AppColors.primary),
                                          ^
lib/screen/reports/report.dart:2949:35: Error:
Constant evaluation error:
                            const Icon(
                                  ^
lib/screen/reports/report.dart:2952:48: Context: The
invocation of 'primary' is not allowed in a constant
expression.
                              color:
                              AppColors.primary,
                                          ^
lib/screen/reports/report.dart:3144:29: Error:
Constant evaluation error:
                      const Text(
                            ^
lib/screen/reports/report.dart:3149:44: Context: The
invocation of 'primary' is not allowed in a constant
expression.
                          color: AppColors.primary,
                                          ^
lib/screen/reports/report.dart:3844:29: Error:
Constant evaluation error:
                      const Text(
                            ^
lib/screen/reports/report.dart:3849:44: Context: The
invocation of 'primary' is not allowed in a constant
expression.
                          color: AppColors.primary,
                                          ^
lib/screen/reports/report.dart:3999:31: Error:
Constant evaluation error:
                    children: const [
                              ^
lib/screen/reports/report.dart:4002:42: Context: The
invocation of 'primary' is not allowed in a constant
expression.
                        color: AppColors.primary,
                                         ^
lib/screen/reports/report.dart:4013:31: Error:
Constant evaluation error:
                    children: const [
                              ^
lib/screen/reports/report.dart:4016:42: Context: The
invocation of 'primary' is not allowed in a constant
expression.
                        color: AppColors.primary,
                                         ^
lib/screen/reports/report_insights_screen.dart:84:20
: Error: Constant evaluation error:
      return const Scaffold(
                   ^
lib/screen/reports/report_insights_screen.dart:87:61
: Context: The invocation of 'primary' is not
allowed in a constant expression.
          child: CircularProgressIndicator(color:
          AppColors.primary),
                                          ^
lib/screen/reports/report_insights_screen.dart:363:1
9: Error: Constant evaluation error:
            const Icon(
                  ^
lib/screen/reports/report_insights_screen.dart:366:3
2: Context: The invocation of 'primary' is not
allowed in a constant expression.
              color: AppColors.primary,
                               ^
lib/screen/reports/report_insights_screen.dart:498:3
4: Error: Constant evaluation error:
                    child: const Icon(
                                 ^
lib/screen/reports/report_insights_screen.dart:500:4
0: Context: The invocation of 'primary' is not
allowed in a constant expression.
                      color: AppColors.primary,
                                       ^
lib/screen/reports/report_insights_screen.dart:545:2
7: Error: Constant evaluation error:
                    const Icon(
                          ^
lib/screen/reports/report_insights_screen.dart:548:4
0: Context: The invocation of 'primary' is not
allowed in a constant expression.
                      color: AppColors.primary,
                                       ^
lib/screen/reports/report_insights_screen.dart:553:3
6: Error: Constant evaluation error:
                      style: const TextStyle(
                                   ^
lib/screen/reports/report_insights_screen.dart:556:4
2: Context: The invocation of 'primary' is not
allowed in a constant expression.
                        color: AppColors.primary,
                                         ^
lib/screen/reports/ai_chat_report_screen.dart:36:20:
Error: Constant evaluation error:
      return const Scaffold(
                   ^
lib/screen/reports/ai_chat_report_screen.dart:39:61:
Context: The invocation of 'primary' is not allowed
in a constant expression.
          child: CircularProgressIndicator(color:
          AppColors.primary),
                                          ^
lib/screen/reports/ai_chat_report_screen.dart:147:39
: Error: Constant evaluation error:
                    prefixIcon: const Icon(
                                      ^
lib/screen/reports/ai_chat_report_screen.dart:149:40
: Context: The invocation of 'primary' is not
allowed in a constant expression.
                      color: AppColors.primary,
                                       ^
lib/screen/reports/ai_chat_report_screen.dart:427:31
: Error: Constant evaluation error:
                        const Text(
                              ^
lib/screen/reports/ai_chat_report_screen.dart:432:46
: Context: The invocation of 'primary' is not
allowed in a constant expression.
                            color:
                            AppColors.primary,
                                          ^
lib/screen/reports/ai_chat_report_screen.dart:656:27
: Error: Constant evaluation error:
                    const Icon(
                          ^
lib/screen/reports/ai_chat_report_screen.dart:658:40
: Context: The invocation of 'primary' is not
allowed in a constant expression.
                      color: AppColors.primary,
                                       ^
lib/screen/inventory/project_report_screen.dart:17:2
0: Error: Constant evaluation error:
      return const Scaffold(
                   ^
lib/screen/inventory/project_report_screen.dart:20:6
1: Context: The invocation of 'primary' is not
allowed in a constant expression.
          child: CircularProgressIndicator(color:
          AppColors.primary),
                                          ^
lib/screen/inventory/ai_voice_entry_screen.dart:2279
:17: Error: Constant evaluation error:
          const Text(
                ^
lib/screen/inventory/ai_voice_entry_screen.dart:2284
:32: Context: The invocation of 'primary' is not
allowed in a constant expression.
              color: AppColors.primary,
                               ^
lib/screen/inventory/ai_voice_entry_screen.dart:2615
:17: Error: Constant evaluation error:
          const Icon(
                ^
lib/screen/inventory/ai_voice_entry_screen.dart:2617
:30: Context: The invocation of 'primary' is not
allowed in a constant expression.
            color: AppColors.primary,
                             ^
lib/screen/inventory/ai_voice_entry_screen.dart:2625
:23: Error: Constant evaluation error:
                const Text(
                      ^
lib/screen/inventory/ai_voice_entry_screen.dart:2630
:38: Context: The invocation of 'primary' is not
allowed in a constant expression.
                    color: AppColors.primary,
                                     ^
lib/screen/inventory/ai_voice_entry_screen.dart:2895
:30: Error: Constant evaluation error:
                child: const Icon(
                             ^
lib/screen/inventory/ai_voice_entry_screen.dart:2897
:36: Context: The invocation of 'primary' is not
allowed in a constant expression.
                  color: AppColors.primary,
                                   ^
lib/screen/inventory/ai_voice_entry_screen.dart:2928
:42: Error: Constant evaluation error:
                            style: const TextStyle(
                                         ^
lib/screen/inventory/ai_voice_entry_screen.dart:2931
:48: Context: The invocation of 'primary' is not
allowed in a constant expression.
                              color:
                              AppColors.primary,
                                          ^
lib/screen/inventory/ai_voice_entry_screen.dart:2997
:39: Error: Constant evaluation error:
                    indicator = const Icon(
                                      ^
lib/screen/inventory/ai_voice_entry_screen.dart:2999
:40: Context: The invocation of 'primary' is not
allowed in a constant expression.
                      color: AppColors.primary,
                                       ^
lib/screen/inventory/ai_voice_entry_screen.dart:3006
:37: Error: Constant evaluation error:
                  indicator = const SizedBox(
                                    ^
lib/screen/inventory/ai_voice_entry_screen.dart:3012
:35: Context: The invocation of 'primary' is not
allowed in a constant expression.
                        AppColors.primary,
                                  ^
lib/screen/inventory/ai_voice_entry_screen.dart:3066
:24: Error: Constant evaluation error:
          child: const Row(
                       ^
lib/screen/inventory/ai_voice_entry_screen.dart:3070
:34: Context: The invocation of 'primary' is not
allowed in a constant expression.
                color: AppColors.primary,
                                 ^
lib/screen/inventory/ai_voice_entry_screen.dart:3288
:28: Error: Constant evaluation error:
              child: const Row(
                           ^
lib/screen/inventory/ai_voice_entry_screen.dart:3292
:38: Context: The invocation of 'primary' is not
allowed in a constant expression.
                    color: AppColors.primary,
                                     ^
lib/screen/inventory/ai_voice_entry_screen.dart:3532
:42: Error: Constant evaluation error:
                            child: const Icon(
                                         ^
lib/screen/inventory/ai_voice_entry_screen.dart:3534
:48: Context: The invocation of 'primary' is not
allowed in a constant expression.
                              color:
                              AppColors.primary,
                                          ^
lib/screen/inventory/ai_voice_entry_screen.dart:3910
:28: Error: Constant evaluation error:
              style: const TextStyle(
                           ^
lib/screen/inventory/ai_voice_entry_screen.dart:3913
:34: Context: The invocation of 'primary' is not
allowed in a constant expression.
                color: AppColors.primary,
                                 ^
lib/screen/inventory/ai_voice_entry_screen.dart:3918
:19: Error: Constant evaluation error:
            const Text(
                  ^
lib/screen/inventory/ai_voice_entry_screen.dart:3923
:34: Context: The invocation of 'primary' is not
allowed in a constant expression.
                color: AppColors.primary,
                                 ^
lib/screen/profile/subscription_screen.dart:157:29:
Error: Constant evaluation error:
      globalTooltipActions: const [
                            ^
lib/screen/profile/subscription_screen.dart:168:38:
Context: The invocation of 'primary' is not allowed
in a constant expression.
          backgroundColor: AppColors.primary,
                                     ^
lib/screen/profile/subscription_screen.dart:354:24:
Error: Constant evaluation error:
          child: const Row(
                       ^
lib/screen/profile/subscription_screen.dart:359:34:
Context: The invocation of 'primary' is not allowed
in a constant expression.
                color: AppColors.primary,
                                 ^
lib/screen/profile/payment_webview_screen.dart:199:2
8: Error: Constant evaluation error:
              child: const Center(
                           ^
lib/screen/profile/payment_webview_screen.dart:203:6
4: Context: The invocation of 'primary' is not
allowed in a constant expression.
                    CircularProgressIndicator(color:
                    AppColors.primary, strokeWidth:
                    2.5),
                                          ^
lib/screen/approvals/approvals_screen.dart:90:27:
Error: Constant evaluation error:
                    const Text(
                          ^
lib/screen/approvals/approvals_screen.dart:95:42:
Context: The invocation of 'primary' is not allowed
in a constant expression.
                        color: AppColors.primary,
                                         ^
lib/screen/approvals/approvals_screen.dart:127:32:
Error: Constant evaluation error:
                  style: const TextStyle(
                               ^
lib/screen/approvals/approvals_screen.dart:129:38:
Context: The invocation of 'primary' is not allowed
in a constant expression.
                    color: AppColors.primary,
                                     ^
lib/common/widgets/app_widgets.dart:367:27: Error:
Constant evaluation error:
    this.color = AppTheme.secondary,
                          ^
lib/common/widgets/autocomplete_name_field.dart:176:
27: Error: Constant evaluation error:
                  ? const Padding(
                          ^
lib/common/widgets/autocomplete_name_field.dart:181:
42: Context: The invocation of 'primary' is not
allowed in a constant expression.
                        color: AppColors.primary,
                                         ^
lib/common/widgets/autocomplete_name_field.dart:302:
25: Error: Constant evaluation error:
                  const Icon(
                        ^
lib/common/widgets/autocomplete_name_field.dart:305:
38: Context: The invocation of 'primary' is not
allowed in a constant expression.
                    color: AppColors.primary,
                                     ^
lib/common/widgets/autocomplete_name_field.dart:308:
25: Error: Constant evaluation error:
                  const Text(
                        ^
lib/common/widgets/autocomplete_name_field.dart:313:
40: Context: The invocation of 'primary' is not
allowed in a constant expression.
                      color: AppColors.primary,
                                       ^
lib/common/widgets/autocomplete_name_field.dart:478:
32: Error: Constant evaluation error:
                  style: const TextStyle(
                               ^
lib/common/widgets/autocomplete_name_field.dart:481:
38: Context: The invocation of 'primary' is not
allowed in a constant expression.
                    color: AppColors.primary,
                                     ^
lib/common/widgets/entry_widgets.dart:2772:28:
Error: Constant evaluation error:
              child: const Text(
                           ^
lib/common/widgets/entry_widgets.dart:2775:36:
Context: The invocation of 'primary' is not allowed
in a constant expression.
                  color: AppColors.primary,
                                   ^
lib/screen/dashboard/notifications_bell.dart:48:26:
Error: Constant evaluation error:
            child: const Icon(
                         ^
lib/screen/dashboard/notifications_bell.dart:50:32:
Context: The invocation of 'primary' is not allowed
in a constant expression.
              color: AppColors.primary,
                               ^
lib/screen/projects/add_project.dart:275:21: Error:
Constant evaluation error:
              const Text(
                    ^
lib/screen/projects/add_project.dart:281:36:
Context: The invocation of 'primary' is not allowed
in a constant expression.
                  color: AppColors.primary,
                                   ^
'''

fixes = {}

for line in log_text.splitlines():
    if line.startswith('lib/'):
        # e.g. lib/screen/projects/project_detail.dart:1600:44:
        parts = line.split(':')
        file_path = 'c:/Users/Muneesha/Desktop/build-track/Build-Track-App/' + parts[0]
        line_num = int(parts[1]) - 1 # 0-indexed
        
        if file_path not in fixes:
            fixes[file_path] = set()
        fixes[file_path].add(line_num)

for file_path, lines in fixes.items():
    if os.path.exists(file_path):
        with open(file_path, 'r', encoding='utf-8') as f:
            content_lines = f.readlines()
        
        for ln in lines:
            if ln < len(content_lines):
                # Replace 'const ' with '' on that specific line
                # Be careful not to replace 'const' inside words.
                content_lines[ln] = re.sub(r'\bconst\s+', '', content_lines[ln])
                
        with open(file_path, 'w', encoding='utf-8') as f:
            f.writelines(content_lines)

print(f"Patched {len(fixes)} files from error log.")
