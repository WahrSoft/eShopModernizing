#!/bin/bash

# Validation script for eShop Legacy MVC Enterprise Infrastructure
# This script validates the deployed infrastructure

set -e

# Configuration
RESOURCE_GROUP=""
ENVIRONMENT=""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

validate_resource_group() {
    log_info "Validating resource group: $RESOURCE_GROUP"
    
    if az group show --name "$RESOURCE_GROUP" &> /dev/null; then
        log_success "Resource group exists"
    else
        log_error "Resource group not found"
        return 1
    fi
}

validate_web_app() {
    log_info "Validating Web App..."
    
    local web_apps=$(az webapp list --resource-group "$RESOURCE_GROUP" --query "[].name" --output tsv)
    
    if [[ -z "$web_apps" ]]; then
        log_error "No Web Apps found"
        return 1
    fi
    
    for app in $web_apps; do
        log_info "Testing Web App: $app"
        
        # Get the URL
        local url=$(az webapp show --name "$app" --resource-group "$RESOURCE_GROUP" --query "defaultHostName" --output tsv)
        
        # Test HTTP response
        local response=$(curl -s -o /dev/null -w "%{http_code}" "https://$url" || echo "000")
        
        if [[ "$response" == "200" ]]; then
            log_success "Web App $app is responding (Status: $response)"
        else
            log_warning "Web App $app returned status: $response"
        fi
    done
}

validate_sql_database() {
    log_info "Validating SQL Database..."
    
    local sql_servers=$(az sql server list --resource-group "$RESOURCE_GROUP" --query "[].name" --output tsv)
    
    if [[ -z "$sql_servers" ]]; then
        log_error "No SQL Servers found"
        return 1
    fi
    
    for server in $sql_servers; do
        log_info "Checking SQL Server: $server"
        
        # Check if server exists and is accessible
        local server_state=$(az sql server show --name "$server" --resource-group "$RESOURCE_GROUP" --query "state" --output tsv)
        
        if [[ "$server_state" == "Ready" ]]; then
            log_success "SQL Server $server is ready"
        else
            log_warning "SQL Server $server state: $server_state"
        fi
        
        # Check databases
        local databases=$(az sql db list --server "$server" --resource-group "$RESOURCE_GROUP" --query "[?name!='master'].name" --output tsv)
        
        for db in $databases; do
            local db_status=$(az sql db show --name "$db" --server "$server" --resource-group "$RESOURCE_GROUP" --query "status" --output tsv)
            
            if [[ "$db_status" == "Online" ]]; then
                log_success "Database $db is online"
            else
                log_warning "Database $db status: $db_status"
            fi
        done
    done
}

validate_redis_cache() {
    log_info "Validating Redis Cache..."
    
    local redis_caches=$(az redis list --resource-group "$RESOURCE_GROUP" --query "[].name" --output tsv)
    
    if [[ -z "$redis_caches" ]]; then
        log_error "No Redis Caches found"
        return 1
    fi
    
    for cache in $redis_caches; do
        log_info "Checking Redis Cache: $cache"
        
        local cache_status=$(az redis show --name "$cache" --resource-group "$RESOURCE_GROUP" --query "provisioningState" --output tsv)
        
        if [[ "$cache_status" == "Succeeded" ]]; then
            log_success "Redis Cache $cache is provisioned successfully"
        else
            log_warning "Redis Cache $cache status: $cache_status"
        fi
    done
}

validate_key_vault() {
    log_info "Validating Key Vault..."
    
    local key_vaults=$(az keyvault list --resource-group "$RESOURCE_GROUP" --query "[].name" --output tsv)
    
    if [[ -z "$key_vaults" ]]; then
        log_error "No Key Vaults found"
        return 1
    fi
    
    for vault in $key_vaults; do
        log_info "Checking Key Vault: $vault"
        
        # Check if we can access the vault
        if az keyvault secret list --vault-name "$vault" &> /dev/null; then
            log_success "Key Vault $vault is accessible"
            
            # List secrets (without values)
            local secrets=$(az keyvault secret list --vault-name "$vault" --query "[].name" --output tsv)
            log_info "Secrets in $vault: $(echo $secrets | tr '\n' ' ')"
        else
            log_warning "Cannot access Key Vault $vault (may be due to network restrictions)"
        fi
    done
}

validate_application_insights() {
    log_info "Validating Application Insights..."
    
    local app_insights=$(az monitor app-insights component show --resource-group "$RESOURCE_GROUP" --query "[].name" --output tsv 2>/dev/null || echo "")
    
    if [[ -z "$app_insights" ]]; then
        log_error "No Application Insights found"
        return 1
    fi
    
    for ai in $app_insights; do
        log_info "Checking Application Insights: $ai"
        
        local ai_status=$(az monitor app-insights component show --app "$ai" --resource-group "$RESOURCE_GROUP" --query "provisioningState" --output tsv)
        
        if [[ "$ai_status" == "Succeeded" ]]; then
            log_success "Application Insights $ai is configured"
        else
            log_warning "Application Insights $ai status: $ai_status"
        fi
    done
}

validate_network() {
    log_info "Validating Virtual Network..."
    
    local vnets=$(az network vnet list --resource-group "$RESOURCE_GROUP" --query "[].name" --output tsv)
    
    if [[ -z "$vnets" ]]; then
        log_error "No Virtual Networks found"
        return 1
    fi
    
    for vnet in $vnets; do
        log_info "Checking Virtual Network: $vnet"
        
        # Check subnets
        local subnets=$(az network vnet subnet list --vnet-name "$vnet" --resource-group "$RESOURCE_GROUP" --query "[].name" --output tsv)
        log_info "Subnets in $vnet: $(echo $subnets | tr '\n' ' ')"
        
        # Check private endpoints
        local private_endpoints=$(az network private-endpoint list --resource-group "$RESOURCE_GROUP" --query "[].name" --output tsv)
        if [[ -n "$private_endpoints" ]]; then
            log_success "Private endpoints found: $(echo $private_endpoints | tr '\n' ' ')"
        else
            log_warning "No private endpoints found"
        fi
    done
}

run_health_checks() {
    log_info "Running application health checks..."
    
    local web_apps=$(az webapp list --resource-group "$RESOURCE_GROUP" --query "[].{name:name,url:defaultHostName}" --output tsv)
    
    while IFS=$'\t' read -r app_name app_url; do
        if [[ -n "$app_name" && -n "$app_url" ]]; then
            log_info "Health check for $app_name at https://$app_url"
            
            # Test basic connectivity
            if curl -f -s "https://$app_url" > /dev/null; then
                log_success "$app_name is responding"
                
                # Test specific endpoints if they exist
                for endpoint in "/health" "/api/health" "/.well-known/ready"; do
                    local status=$(curl -s -o /dev/null -w "%{http_code}" "https://$app_url$endpoint" || echo "000")
                    if [[ "$status" == "200" ]]; then
                        log_success "Health endpoint $endpoint is responding"
                        break
                    fi
                done
            else
                log_warning "$app_name is not responding or returned an error"
            fi
        fi
    done <<< "$web_apps"
}

# Main validation function
main() {
    echo "=========================================="
    echo "eShop Infrastructure Validation"
    echo "=========================================="
    echo
    
    if [[ $# -eq 0 ]]; then
        echo "Usage: $0 [dev|prod]"
        echo "  dev   Validate development environment"
        echo "  prod  Validate production environment"
        exit 1
    fi
    
    ENVIRONMENT=$1
    
    case $ENVIRONMENT in
        dev)
            RESOURCE_GROUP="rg-eshop-dev"
            ;;
        prod)
            RESOURCE_GROUP="rg-eshop-prod"
            ;;
        *)
            log_error "Invalid environment: $ENVIRONMENT. Use 'dev' or 'prod'"
            exit 1
            ;;
    esac
    
    log_info "Validating environment: $ENVIRONMENT"
    log_info "Resource group: $RESOURCE_GROUP"
    echo
    
    # Run all validations
    local validation_failed=false
    
    validate_resource_group || validation_failed=true
    validate_network || validation_failed=true
    validate_key_vault || validation_failed=true
    validate_sql_database || validation_failed=true
    validate_redis_cache || validation_failed=true
    validate_application_insights || validation_failed=true
    validate_web_app || validation_failed=true
    run_health_checks || validation_failed=true
    
    echo
    if [[ "$validation_failed" == true ]]; then
        log_warning "Some validations failed or returned warnings"
        exit 1
    else
        log_success "All validations passed successfully!"
    fi
}

# Run main function with all arguments
main "$@"