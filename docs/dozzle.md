# Dozzle

## Caddy

- See requests to the breedbase server.

    ```sql
    select unnest(request)
    from logs
    where request.tls.server_name like '%breedbase%'
    ```

## Database

- See failed authentications:

    ```sql
    select * from logs
    where ps = 'authentication' and error_severity = 'fatal'
    order by timestamp desc
    limit 100
    ```

## OAuth2-Proxy

```sql
SELECT unnest(request) FROM logs where request.host = 'auth.localtester.com' order by ts desc limit 10
```
