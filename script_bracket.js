const fs = require('fs');
const path = 'C:/Users/Muneesha/Desktop/build-track/Build-Track-App/lib/screen/dashboard/homescreen.dart';
let content = fs.readFileSync(path, 'utf8');

// The code currently looks like:
// }).toList(),
// ),
// ),
// ),
// ],
// ),
// ),
// ),
// );
// }
// Widget _costCard(

// I need to change it to:
// }).toList(),
// ],
// ),

content = content.replace(
    /}\)\.toList\(\),\s*\),\s*\),\s*\),\s*\]\,\s*\)\,\s*\)\,\s*\)\,\s*\)\;\s*\}/,
    `}).toList(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }`
);

fs.writeFileSync(path, content, 'utf8');
