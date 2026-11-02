apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: java-login-ingress
  namespace: production-v3
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/load-balancer-name: production-v3-java-alb

    alb.ingress.kubernetes.io/subnets: subnet-06611a4f5dbd46118,subnet-032bf1cf855bf96f4

    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP":80}]'
    alb.ingress.kubernetes.io/inbound-cidrs: "__ADMIN_CIDR__"

    alb.ingress.kubernetes.io/healthcheck-path: /login
    alb.ingress.kubernetes.io/success-codes: "200"

    alb.ingress.kubernetes.io/target-group-attributes: stickiness.enabled=true,stickiness.lb_cookie.duration_seconds=3600

spec:
  ingressClassName: alb
  rules:
    - http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: java-login-service
                port:
                  number: 80
