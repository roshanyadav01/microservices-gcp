name: GCP Microservices Multi-Env CI/CD

on:
  push:
    branches: [ "main" ]

permissions:
  id-token: write
  contents: read

env:
  REGION: us-central1
  REPO: microservices
  CLUSTER_NAME: microservices-cluster

jobs:

# -----------------------------------
# 1. Terraform (Per Environment)
# -----------------------------------
  terraform:
    runs-on: ubuntu-latest

    strategy:
      matrix:
        env: [dev, uat, prod]

    environment: ${{ matrix.env }}

    steps:
      - name: Checkout
        uses: actions/checkout@v3

      # OIDC Auth (NO JSON KEY)
      - name: Authenticate to GCP
        uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: ${{ secrets.WIF_PROVIDER }}
          service_account: ${{ secrets.SERVICE_ACCOUNT }}

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3

      - name: Terraform Init & Apply
        run: |
          cd terraform/envs/${{ matrix.env }}
          terraform init
          terraform apply -auto-approve

# -----------------------------------
# 2. Build & Push (Parallel Services)
# -----------------------------------
  build:
    needs: terraform
    runs-on: ubuntu-latest

    strategy:
      matrix:
        service: [user, payment, order]

    steps:
      - uses: actions/checkout@v3

      - name: Authenticate to GCP
        uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: ${{ secrets.WIF_PROVIDER }}
          service_account: ${{ secrets.SERVICE_ACCOUNT }}

      - name: Configure Docker
        run: gcloud auth configure-docker $REGION-docker.pkg.dev

      - name: Build & Push Image
        run: |
          IMAGE=$REGION-docker.pkg.dev/${{ secrets.GCP_PROJECT }}/$REPO/${{ matrix.service }}:${{ github.sha }}
          
          docker build -t $IMAGE ./services/${{ matrix.service }}
          docker push $IMAGE

# -----------------------------------
# 3. Deploy (Per Env + Parallel Services)
# -----------------------------------
  deploy:
    needs: build
    runs-on: ubuntu-latest

    strategy:
      matrix:
        env: [dev, uat, prod]
        service: [user, payment, order]

    environment: ${{ matrix.env }}

    steps:
      - uses: actions/checkout@v3

      - name: Authenticate to GCP
        uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: ${{ secrets.WIF_PROVIDER }}
          service_account: ${{ secrets.SERVICE_ACCOUNT }}

      - name: Get GKE Credentials
        uses: google-github-actions/get-gke-credentials@v2
        with:
          cluster_name: ${{ env.CLUSTER_NAME }}
          location: ${{ env.REGION }}

      - name: Helm Deploy
        run: |
          IMAGE_REPO=$REGION-docker.pkg.dev/${{ secrets.GCP_PROJECT }}/$REPO/${{ matrix.service }}

          helm upgrade --install ${{ matrix.service }} ./helm/${{ matrix.service }} \
            --set image.repository=$IMAGE_REPO \
            --set image.tag=${{ github.sha }} \
            --namespace ${{ matrix.env }} \
            --create-namespace

# -----------------------------------
# 4. Rollout (Scale after Deploy)
# -----------------------------------
  rollout:
    needs: deploy
    runs-on: ubuntu-latest

    strategy:
      matrix:
        env: [dev, uat, prod]

    environment: ${{ matrix.env }}

    steps:
      - name: Authenticate to GCP
        uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: ${{ secrets.WIF_PROVIDER }}
          service_account: ${{ secrets.SERVICE_ACCOUNT }}

      - name: Get GKE Credentials
        uses: google-github-actions/get-gke-credentials@v2
        with:
          cluster_name: microservices-cluster
          location: us-central1

      - name: Scale Deployments
        run: |
          kubectl scale deploy user --replicas=2 -n ${{ matrix.env }}
          kubectl scale deploy payment --replicas=2 -n ${{ matrix.env }}
          kubectl scale deploy order --replicas=2 -n ${{ matrix.env }}

# -----------------------------------
# 5. Verify
# -----------------------------------
  verify:
    needs: rollout
    runs-on: ubuntu-latest

    strategy:
      matrix:
        env: [dev, uat, prod]

    environment: ${{ matrix.env }}

    steps:
      - name: Authenticate to GCP
        uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: ${{ secrets.WIF_PROVIDER }}
          service_account: ${{ secrets.SERVICE_ACCOUNT }}

      - name: Get GKE Credentials
        uses: google-github-actions/get-gke-credentials@v2
        with:
          cluster_name: microservices-cluster
          location: us-central1

      - name: Verify Pods
        run: |
          kubectl get pods -n ${{ matrix.env }}