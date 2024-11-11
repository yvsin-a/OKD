#!/bin/bash

# Variables
HTPASSWD_FILE="file location"    
OPENSHIFT_SECRET_NAME="htpasswd-secret"         
NAMESPACE="openshift-config"                     
USER_ACTION=$1                                   
shift                                            

# Fonction pour vérifier si le fichier htpasswd existe
function check_htpasswd_file() {
  if [[ ! -f $HTPASSWD_FILE ]]; then
    echo "Le fichier htpasswd n'existe pas. Création d'un nouveau fichier."
    touch $HTPASSWD_FILE
  fi
}

# Création ou mise à jour d'un utilisateur
function add_or_update_user() {
  local username=$1
  local password=$2
  echo "Ajout ou mise à jour de l'utilisateur : $username"
  htpasswd -bB $HTPASSWD_FILE $username $password
}

# Suppression d'un utilisateur
function delete_user() {
  local username=$1
  echo "Suppression de l'utilisateur : $username"
  htpasswd -D $HTPASSWD_FILE $username
}

# Mise à jour du secret OpenShift pour prendre en compte les modifications
function update_openshift_secret() {
  echo "Mise à jour du secret htpasswd dans OpenShift"
  oc create secret generic $OPENSHIFT_SECRET_NAME --from-file=htpasswd=$HTPASSWD_FILE -n $NAMESPACE --dry-run=client -o yaml | oc apply -f -
  
  echo "Redémarrage de l'authentification pour appliquer les modifications"
  oc delete pod -l app=oauth-openshift -n openshift-authentication
}

# Vérification des paramètres et exécution de l'action
check_htpasswd_file

case $USER_ACTION in
  add|update)
    while [[ $# -gt 0 ]]; do
      USERNAME=$1
      PASSWORD=$2
      if [[ -z "$USERNAME" || -z "$PASSWORD" ]]; then
        echo "Usage: $0 add|update <username1> <password1> [<username2> <password2> ...]"
        exit 1
      fi
      add_or_update_user "$USERNAME" "$PASSWORD"
      shift 2
    done
    ;;
  delete)
    while [[ $# -gt 0 ]]; do
      USERNAME=$1
      if [[ -z "$USERNAME" ]]; then
        echo "Usage: $0 delete <username1> [<username2> ...]"
        exit 1
      fi
      delete_user "$USERNAME"
      shift
    done
    ;;
  *)
    echo "Action invalide. Utilisez add, update ou delete."
    exit 1
    ;;
esac

# Mise à jour du secret et redémarrage du service d'authentification
update_openshift_secret

echo "Opération terminée avec succès."
