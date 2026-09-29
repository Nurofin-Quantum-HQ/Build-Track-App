import re

with open('c:/Users/Muneesha/Desktop/build-track/Build-Track-App/lib/screen/dashboard/homescreen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

search = '''                      indicatorIcon: isLoss ? Icons.trending_down : Icons.trending_up,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (project != null) ...['''

replace = '''                      indicatorIcon: isLoss ? Icons.trending_down : Icons.trending_up,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _costCard(
                'UPCOMING PAY / PLANNED',
                project != null ? formatCurrency(project.remainingBudget < 0 ? 0 : project.remainingBudget) : '₹—',
                'Planned to spend',
                false,
                isInvoice: true,
                indicatorIcon: Icons.schedule,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: const SizedBox.shrink()),
          ],
        ),
        const SizedBox(height: 14),
        if (project != null) ...['''

if search in content:
    content = content.replace(search, replace)
    with open('c:/Users/Muneesha/Desktop/build-track/Build-Track-App/lib/screen/dashboard/homescreen.dart', 'w', encoding='utf-8') as f:
        f.write(content)
    print("Patched homescreen.dart")
else:
    print("Could not find the search string")
