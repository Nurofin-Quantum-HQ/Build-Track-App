import re

with open('c:/Users/Muneesha/Desktop/build-track/Build-Track-App/lib/common/themes/app_gradients.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Change static const LinearGradient -> static LinearGradient get
content = content.replace('static const LinearGradient', 'static LinearGradient get')

# Change AppColors.primaryBlue -> AppColors.primary
content = content.replace('AppColors.primaryBlue', 'AppColors.primary')
# We should probably also change primaryPurple and primaryLightBlue to variations of primary if possible?
# primaryPurple might be expected to be secondary color. 
# Wait, if we just change primaryBlue to AppColors.primary, and maybe primaryPurple to AppColors.primary.withOpacity(0.8) ?
# Or let's see how primaryPurple and primaryLightBlue are defined in AppColors.

with open('c:/Users/Muneesha/Desktop/build-track/Build-Track-App/lib/common/themes/app_gradients.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print("Fixed app_gradients getters")
