import random

esci_count = 0

for _ in range(100):
    choice = random.randint(0, 1)
    
    if choice == 1:
        print("Esci")
        esci_count += 1
    else:
        print("Non uscire")

if esci_count > 5:
    print(f"Risultato: {esci_count}/100. Esci veramente mo!")
else:
    print(f"Risultato: {esci_count}/100. Resta a casa.")