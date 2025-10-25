# Microservice Migration Guide

This guide explains how to extract services from the Vinylhound monorepo into independent microservices.

## Migration Phases

### Phase 1: Preparation

#### 1.1 Service Isolation
- Ensure each service has clear boundaries
- Minimize cross-service dependencies
- Document service interfaces and contracts

#### 1.2 Database Preparation
- Identify shared data and dependencies
- Plan database separation strategy
- Create data migration scripts

#### 1.3 Infrastructure Setup
- Set up service registry (Consul, etcd)
- Configure API Gateway for service discovery
- Implement monitoring and logging

### Phase 2: Service Extraction

#### 2.1 Extract User Service

**Step 1: Create New Repository**
```bash
# Create new repository
git clone https://github.com/vinylhound/user-service.git
cd user-service

# Copy service code
cp -r ../vinylhound/Vinylhound-Backend/services/user-service/* .
cp -r ../vinylhound/Vinylhound-Backend/shared/go ./shared
```

**Step 2: Update Dependencies**
```go
// go.mod
module vinylhound/user-service

require (
    vinylhound/shared v0.0.0
    // ... other dependencies
)

replace vinylhound/shared => ./shared
```

**Step 3: Database Migration**
```sql
-- Create user service database
CREATE DATABASE vinylhound_users;

-- Migrate user-related tables
CREATE TABLE users (...);
CREATE TABLE sessions (...);
CREATE TABLE user_content (...);
```

**Step 4: Service Configuration**
```yaml
# docker-compose.yml
version: '3.8'
services:
  user-service:
    build: .
    environment:
      DB_HOST: postgres-users
      DB_PORT: 5432
      DB_NAME: vinylhound_users
      SERVICE_REGISTRY: consul:8500
    ports:
      - "8001:8001"
```

#### 2.2 Extract Catalog Service

**Step 1: Create New Repository**
```bash
git clone https://github.com/vinylhound/catalog-service.git
cd catalog-service

cp -r ../vinylhound/Vinylhound-Backend/services/catalog-service/* .
cp -r ../vinylhound/Vinylhound-Backend/shared/go ./shared
```

**Step 2: Database Migration**
```sql
-- Create catalog service database
CREATE DATABASE vinylhound_catalog;

-- Migrate catalog-related tables
CREATE TABLE albums (...);
CREATE TABLE artists (...);
CREATE TABLE songs (...);
```

#### 2.3 Extract Rating Service

**Step 1: Create New Repository**
```bash
git clone https://github.com/vinylhound/rating-service.git
cd rating-service

cp -r ../vinylhound/Vinylhound-Backend/services/rating-service/* .
cp -r ../vinylhound/Vinylhound-Backend/shared/go ./shared
```

**Step 2: Database Migration**
```sql
-- Create rating service database
CREATE DATABASE vinylhound_ratings;

-- Migrate rating-related tables
CREATE TABLE ratings (...);
CREATE TABLE reviews (...);
CREATE TABLE user_preferences (...);
```

### Phase 3: Service Communication

#### 3.1 Implement Service Discovery

**Consul Configuration**
```hcl
# consul.hcl
datacenter = "vinylhound"
server = true
bootstrap_expect = 1
ui_config {
  enabled = true
}
```

**Service Registration**
```go
// Register service with Consul
func registerService(serviceName, serviceID, address string, port int) error {
    config := consul.DefaultConfig()
    config.Address = "consul:8500"
    
    client, err := consul.NewClient(config)
    if err != nil {
        return err
    }
    
    registration := &consul.AgentServiceRegistration{
        ID:      serviceID,
        Name:    serviceName,
        Address: address,
        Port:    port,
        Check: &consul.AgentServiceCheck{
            HTTP:                           fmt.Sprintf("http://%s:%d/health", address, port),
            Interval:                       "10s",
            Timeout:                        "3s",
            DeregisterCriticalServiceAfter: "30s",
        },
    }
    
    return client.Agent().ServiceRegister(registration)
}
```

#### 3.2 Update API Gateway

**Service Discovery Integration**
```go
// API Gateway with service discovery
func createProxy(serviceName string) *httputil.ReverseProxy {
    return &httputil.ReverseProxy{
        Director: func(req *http.Request) {
            // Discover service endpoint
            endpoint, err := discoverService(serviceName)
            if err != nil {
                http.Error(w, "Service unavailable", http.StatusServiceUnavailable)
                return
            }
            
            req.URL.Scheme = "http"
            req.URL.Host = endpoint
        },
    }
}
```

#### 3.3 Inter-Service Communication

**HTTP Client with Service Discovery**
```go
type ServiceClient struct {
    serviceName string
    consul      *consul.Client
}

func (c *ServiceClient) Get(endpoint string) (*http.Response, error) {
    serviceURL, err := c.discoverService()
    if err != nil {
        return nil, err
    }
    
    url := fmt.Sprintf("%s%s", serviceURL, endpoint)
    return http.Get(url)
}
```

### Phase 4: Data Synchronization

#### 4.1 Event-Driven Architecture

**Event Publishing**
```go
type EventPublisher struct {
    publisher messaging.Publisher
}

func (p *EventPublisher) PublishUserCreated(user *models.User) error {
    event := &events.UserCreated{
        UserID:    user.ID,
        Username:  user.Username,
        CreatedAt: user.CreatedAt,
    }
    
    return p.publisher.Publish("user.created", event)
}
```

**Event Consumption**
```go
type EventConsumer struct {
    consumer messaging.Consumer
}

func (c *EventConsumer) HandleUserCreated(event *events.UserCreated) error {
    // Update local cache or database
    return c.updateUserCache(event)
}
```

#### 4.2 Database Synchronization

**Read Replicas**
```yaml
# Database configuration for read replicas
services:
  postgres-master:
    image: postgres:16
    environment:
      POSTGRES_DB: vinylhound_users
    volumes:
      - user-data:/var/lib/postgresql/data
      
  postgres-replica:
    image: postgres:16
    environment:
      POSTGRES_DB: vinylhound_users
    command: |
      bash -c "
        pg_basebackup -h postgres-master -D /var/lib/postgresql/data -U replicator -v -P -W
        postgres
      "
```

### Phase 5: Monitoring and Observability

#### 5.1 Distributed Tracing

**Jaeger Configuration**
```yaml
# jaeger.yml
version: '3.8'
services:
  jaeger:
    image: jaegertracing/all-in-one:latest
    ports:
      - "16686:16686"
      - "14268:14268"
    environment:
      - COLLECTOR_OTLP_ENABLED=true
```

**Tracing Integration**
```go
import "go.opentelemetry.io/otel/trace"

func (h *UserHandler) CreateUser(w http.ResponseWriter, r *http.Request) {
    ctx, span := tracer.Start(r.Context(), "user.create")
    defer span.End()
    
    // ... handler logic
}
```

#### 5.2 Metrics Collection

**Prometheus Configuration**
```yaml
# prometheus.yml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'user-service'
    static_configs:
      - targets: ['user-service:8001']
  - job_name: 'catalog-service'
    static_configs:
      - targets: ['catalog-service:8002']
  - job_name: 'rating-service'
    static_configs:
      - targets: ['rating-service:8003']
```

**Metrics Integration**
```go
import "github.com/prometheus/client_golang/prometheus"

var (
    httpRequestsTotal = prometheus.NewCounterVec(
        prometheus.CounterOpts{
            Name: "http_requests_total",
            Help: "Total number of HTTP requests",
        },
        []string{"method", "endpoint", "status"},
    )
)
```

### Phase 6: Deployment and Orchestration

#### 6.1 Kubernetes Deployment

**User Service Deployment**
```yaml
# k8s/user-service-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: user-service
spec:
  replicas: 3
  selector:
    matchLabels:
      app: user-service
  template:
    metadata:
      labels:
        app: user-service
    spec:
      containers:
      - name: user-service
        image: vinylhound/user-service:latest
        ports:
        - containerPort: 8001
        env:
        - name: DB_HOST
          value: "postgres-users"
        - name: SERVICE_REGISTRY
          value: "consul:8500"
```

**Service Configuration**
```yaml
# k8s/user-service-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: user-service
spec:
  selector:
    app: user-service
  ports:
  - port: 8001
    targetPort: 8001
  type: ClusterIP
```

#### 6.2 Service Mesh (Istio)

**Istio Configuration**
```yaml
# istio/user-service-virtual-service.yaml
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: user-service
spec:
  hosts:
  - user-service
  http:
  - match:
    - uri:
        prefix: /api/v1/users
    route:
    - destination:
        host: user-service
        port:
          number: 8001
```

### Phase 7: Testing and Validation

#### 7.1 Contract Testing

**Pact Testing**
```go
func TestUserServiceContract(t *testing.T) {
    // Set up Pact
    pact := &dsl.Pact{
        Consumer: "catalog-service",
        Provider: "user-service",
    }
    defer pact.Teardown()
    
    // Define expected interaction
    pact.
        AddInteraction().
        Given("user exists").
        UponReceiving("a request for user profile").
        WithRequest(dsl.Request{
            Method: "GET",
            Path:   "/api/v1/users/profile",
            Headers: dsl.MapMatcher{
                "Authorization": dsl.String("Bearer token"),
            },
        }).
        WillRespondWith(dsl.Response{
            Status: 200,
            Body: dsl.Match(userProfile),
        })
    
    // Test the interaction
    test := func() error {
        client := NewUserServiceClient(pact.Server.URL)
        profile, err := client.GetProfile("token")
        assert.NoError(t, err)
        assert.Equal(t, expectedProfile, profile)
        return nil
    }
    
    pact.Verify(test)
}
```

#### 7.2 Load Testing

**Artillery Configuration**
```yaml
# artillery.yml
config:
  target: 'http://localhost:8080'
  phases:
    - duration: 60
      arrivalRate: 10
scenarios:
  - name: "User registration and login"
    weight: 50
    flow:
      - post:
          url: "/api/v1/auth/signup"
          json:
            username: "user{{ $randomString() }}"
            password: "password123"
      - post:
          url: "/api/v1/auth/login"
          json:
            username: "{{ username }}"
            password: "password123"
```

## Migration Checklist

### Pre-Migration
- [ ] Service boundaries clearly defined
- [ ] Database schemas documented
- [ ] API contracts documented
- [ ] Dependencies identified
- [ ] Migration plan created

### During Migration
- [ ] Service extracted to separate repository
- [ ] Database separated
- [ ] Service discovery implemented
- [ ] API Gateway updated
- [ ] Monitoring configured
- [ ] Tests updated

### Post-Migration
- [ ] Service deployed independently
- [ ] Load testing completed
- [ ] Performance monitoring active
- [ ] Documentation updated
- [ ] Team trained on new architecture

## Rollback Strategy

### Immediate Rollback
- Revert API Gateway configuration
- Switch back to monorepo services
- Restore database connections

### Data Rollback
- Restore database from backup
- Replay events to synchronize data
- Validate data consistency

### Service Rollback
- Deploy previous service version
- Update service registry
- Verify service health

## Best Practices

### Service Design
- Keep services stateless
- Use database per service
- Implement circuit breakers
- Design for failure

### Communication
- Use async communication when possible
- Implement retry mechanisms
- Use service discovery
- Monitor service health

### Data Management
- Implement eventual consistency
- Use event sourcing for audit
- Plan for data migration
- Backup and restore procedures

### Monitoring
- Implement distributed tracing
- Monitor service dependencies
- Set up alerting
- Track business metrics
