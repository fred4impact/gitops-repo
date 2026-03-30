```bash
# Dev
helm upgrade --install springboot-dev ./healthcare-booking-helm \
  -f values-dev.yaml -n healthcare-dev --create-namespace

# Staging
helm upgrade --install springboot-staging ./healthcare-booking-helm \
  -f values-staging.yaml -n healthcare-staging --create-namespace

# Prod
helm upgrade --install springboot-prod ./healthcare-booking-helm \
  -f values-prod.yaml -n healthcare-prod --create-namespace