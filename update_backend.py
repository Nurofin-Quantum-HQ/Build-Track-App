import re

# 1. Update User.js model
with open('c:/Users/Muneesha/Desktop/build-track/Build-Track/backend/models/User.js', 'r', encoding='utf-8') as f:
    user_js = f.read()

if 'themePreference:' not in user_js:
    user_js = user_js.replace('companyLogo: { type: String, default: null },', 
                              'companyLogo: { type: String, default: null },\n    themePreference: { type: String, default: null },')
    with open('c:/Users/Muneesha/Desktop/build-track/Build-Track/backend/models/User.js', 'w', encoding='utf-8') as f:
        f.write(user_js)

# 2. Update authRoutes.js safeUser
with open('c:/Users/Muneesha/Desktop/build-track/Build-Track/backend/routes/authRoutes.js', 'r', encoding='utf-8') as f:
    auth_routes = f.read()

if 'themePreference:' not in auth_routes:
    auth_routes = auth_routes.replace('companyLogo: user.companyLogo || (user.createdBy && typeof user.createdBy === \'object\' ? \nuser.createdBy.companyLogo : null) || null,',
                                      'companyLogo: user.companyLogo || (user.createdBy && typeof user.createdBy === \'object\' ? \nuser.createdBy.companyLogo : null) || null,\n      themePreference: user.themePreference || null,')
    # handle the line breaking variations
    auth_routes = auth_routes.replace("companyLogo: user.companyLogo || (user.createdBy && typeof user.createdBy === 'object' ? user.createdBy.companyLogo : null) || null,",
                                      "companyLogo: user.companyLogo || (user.createdBy && typeof user.createdBy === 'object' ? user.createdBy.companyLogo : null) || null,\n      themePreference: user.themePreference || null,")

    with open('c:/Users/Muneesha/Desktop/build-track/Build-Track/backend/routes/authRoutes.js', 'w', encoding='utf-8') as f:
        f.write(auth_routes)

# 3. Update userController.js safeUser and updateProfile
with open('c:/Users/Muneesha/Desktop/build-track/Build-Track/backend/controllers/userController.js', 'r', encoding='utf-8') as f:
    user_ctrl = f.read()

if 'themePreference:' not in user_ctrl:
    user_ctrl = user_ctrl.replace('companyLogo:      user.companyLogo || (user.createdBy && typeof user.createdBy === \'object\' ? user.createdBy.companyLogo : null) || null,',
                                  'companyLogo:      user.companyLogo || (user.createdBy && typeof user.createdBy === \'object\' ? user.createdBy.companyLogo : null) || null,\n  themePreference:  user.themePreference || null,')
    
    user_ctrl = user_ctrl.replace('const { name, email, profilePhoto, role, phone, companyName, companyFontStyle, companyLogo, preferences } = req.body;',
                                  'const { name, email, profilePhoto, role, phone, companyName, companyFontStyle, companyLogo, preferences, themePreference } = req.body;')
                                  
    theme_update = '''
    if (themePreference !== undefined) {
      user.themePreference = themePreference === null ? null : String(themePreference).trim();
    }
'''
    user_ctrl = user_ctrl.replace('if (name !== undefined) {', theme_update + '    if (name !== undefined) {')
    
    with open('c:/Users/Muneesha/Desktop/build-track/Build-Track/backend/controllers/userController.js', 'w', encoding='utf-8') as f:
        f.write(user_ctrl)

print("Backend updated for themePreference")
