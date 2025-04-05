import sys; lines = open('MirrorChild/ContentView_new.swift', 'r').readlines(); lines.insert(1432, '                                }
'); open('MirrorChild/ContentView_new.swift', 'w').writelines(lines)
