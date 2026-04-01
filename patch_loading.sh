#!/bin/bash
sed -i "s/if (!isActive && authProvider != 'google') {/final bool emailVerified = profile['email_verified'] ?? true;\n      if (!isActive \&\& !emailVerified) {/g" /home/kiprono-alex/Projects/HooK-UP/HookupPRJ/lib/screens/loading_screen.dart
