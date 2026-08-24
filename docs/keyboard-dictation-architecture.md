# Dictée par extension de clavier

## Décision

Entrevoix aura une extension de clavier iOS. L'extension sera la surface de
saisie et d'insertion de texte ; l'application conteneur possédera le
microphone, la session audio, la transcription et les réglages. Ce document
décrit l'architecture cible. Le target d'extension est désormais présent ; le
service de capture et de transcription de l'application conteneur reste à
implémenter.

L'extension ne tente jamais d'enregistrer directement. iOS ne donne pas l'accès
au microphone à une extension de clavier. Elle utilise un App Group et l'option
**Accès complet** pour communiquer avec l'application conteneur déjà active.

## Parcours utilisateur

1. Lors de l'onboarding, l'application conteneur demande l'accès au microphone,
   configure l'extension et prépare la session de dictée.
2. L'utilisateur active le clavier Entrevoix dans n'importe quel champ de texte.
3. Un bouton de microphone remplace les touches du clavier pendant la dictée.
4. Si l'application conteneur est prête, le bouton affiche un micro plein. Une
   pression crée une demande de dictée, sans quitter l'application hôte.
5. L'application conteneur enregistre et transcrit en arrière-plan. L'extension
   affiche l'état de la dictée, puis insère le résultat à la position du curseur.
6. Si l'application n'est pas prête, le bouton affiche un micro contouré. Une
   pression ouvre brièvement Entrevoix pour réactiver le microphone ; l'utilisateur
   revient ensuite à l'application hôte avant de dicter.

Le repli de l'étape 6 est attendu après un arrêt forcé, un redémarrage, une
interruption audio ou une suspension décidée par iOS. Le parcours sans bascule
est l'expérience privilégiée, mais ne peut pas être garanti par le système.

## Protocole inter-processus

Les deux targets appartiennent au même App Group. Les données persistantes sont
écrites de manière atomique dans son conteneur partagé ; elles ne contiennent
jamais la clé API, qui reste dans le Keychain de l'application conteneur.

```text
Keyboard extension                     Containing app
------------------                     --------------
tap microphone
      │
      ├─ write DictationRequest ─────► observe/read request
      │                                      │
      │                                      ├─ record + transcribe
      │                                      └─ write DictationResult
      ◄──── observe/read result ──────┘
      │
textDocumentProxy.insertText(result)
```

Chaque demande possède un identifiant stable et les états suivants :

- `requested` — écrite par l'extension ;
- `recording` — l'application conteneur possède le micro ;
- `transcribing` — l'audio est en cours de traitement ;
- `completed(transcript)` — texte prêt à insérer ;
- `failed(userFacingMessage)` ou `cancelled` — fin sans insertion.

L'extension doit tolérer son arrêt à tout moment. Elle relit les demandes et les
résultats à son démarrage, n'insère un résultat qu'une fois, et ignore toute
réponse qui ne correspond pas à sa demande active.

## Responsabilités par target

| Target | Responsabilités |
| --- | --- |
| Application iOS | Onboarding, autorisation micro, session audio d'arrière-plan, transcription, nettoyage, Keychain, réglages et gestion des erreurs. |
| Extension de clavier | Bouton micro, état visuel, demande de dictée, lecture du résultat, insertion dans le champ de texte et bouton de changement de clavier. |
| Composants partagés | Modèles de préférences, demandes/résultats, règles de nettoyage et contrats de persistance. |

## Garde-fous

- L'enregistrement est toujours visible par l'indicateur système de microphone.
- Le microphone est arrêté dès la fin, l'annulation ou l'erreur d'une dictée.
- Le clavier reste utilisable pour la saisie manuelle sans Accès complet ; la
  dictée affiche alors une explication et un lien vers l'onboarding.
- Le clavier ne promet pas de fonctionner dans les champs sécurisés, les pavés
  téléphoniques ou les applications qui désactivent les claviers tiers.
- L'app conteneur ne doit pas utiliser une lecture audio silencieuse uniquement
  pour contourner la gestion d'arrière-plan d'iOS.

## Références

- [Apple — Configuring open access for a custom keyboard](https://developer.apple.com/documentation/uikit/configuring-open-access-for-a-custom-keyboard)
- [Apple — Creating a custom keyboard](https://developer.apple.com/documentation/uikit/creating-a-custom-keyboard)
- [Typeless — When does app switching happen?](https://www.typeless.com/help/release-notes/ios/when-does-app-switching-happen)
