*** Settings ***
Documentation     Test Suite for Order Status Transitions in vKho API
...               Validates progression through all order states
Library           RequestsLibrary
Library           Collections
Library           OperatingSystem
Library           String
Library           DateTime

*** Variables ***
${BASE_URL}             https://api.vkho.net
${USERNAME}             huynh22.manager
${PASSWORD}             Snowfox1991
${WAREHOUSE_ID}         6
${RESULTS_DIR}          ${CURDIR}${/}results
${TEST_ORDER_ID}        ${EMPTY}

*** Keywords ***
Setup API Session
    [Documentation]     Create API session and authenticate
    Create Session      vkho             ${BASE_URL}      verify=True    disable_warnings=True
    ${headers}=         Create Dictionary    Content-Type=application/json
    ${body}=            Create Dictionary    username=${USERNAME}    password=${PASSWORD}
    ${response}=        POST On Session    vkho    /auth/login    json=${body}    headers=${headers}    expected_status=201
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    ${token}=           Set Variable     Bearer ${json}[access_token]
    Set Global Variable  ${AUTH_TOKEN}    ${token}
    Create Directory    ${RESULTS_DIR}

Generate Order Data
    ${timestamp}=       Evaluate         int(time.time())    time
    ${order_code}=      Set Variable     ORDTRANS${timestamp}
    ${product_order}=   Create Dictionary    total=5    boothCode=BOOTH${timestamp}    sku=SKU${timestamp}
    ${product_orders}=  Create List      ${product_order}
    ${order_data}=      Create Dictionary
    ...                 nameCustomer=Transition Test ${timestamp}
    ...                 code=${order_code}
    ...                 boothCode=BOOTH${timestamp}
    ...                 deliveryAdress=Test Address
    ...                 deliveryTime=2025-04-01T12:00:00.000Z
    ...                 warehouseId=${WAREHOUSE_ID}
    ...                 productOrders=${product_orders}
    RETURN            ${order_data}

Create Initial Order
    ${order_data}=      Generate Order Data
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        POST On Session    vkho    /orders/create    json=${order_data}    headers=${headers}    expected_status=201
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Set Global Variable  ${TEST_ORDER_ID}    ${json}[id]
    RETURN            ${json}

Update Order Status
    [Arguments]         ${order_id}    ${status}
    ${update_data}=     Create Dictionary    id=${order_id}    status=${status}    boothCode=BOOTH${order_id}
    ...                 deliveryAdress=Test Address    deliveryTime=2025-04-01T12:00:00.000Z
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        PUT On Session    vkho    /orders/update    json=${update_data}    headers=${headers}    expected_status=200
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Be Equal     ${json}[status]    ${status}
    RETURN            ${json}

*** Test Cases ***
01 - Setup Environment
    [Tags]              setup
    Setup API Session

02 - Test Full Status Transition
    [Documentation]     Test progression through all order statuses
    [Tags]              status    positive
    ${order}=           Create Initial Order
    Should Be Equal     ${order}[status]    CREATED
    
    ${picking_order}=   Update Order Status    ${TEST_ORDER_ID}    PICKING
    Should Be Equal     ${picking_order}[status]    PICKING
    
    ${delivering_order}=    Update Order Status    ${TEST_ORDER_ID}    DELIVERING
    Should Be Equal     ${delivering_order}[status]    DELIVERING
    
    ${completed_order}=     Update Order Status    ${TEST_ORDER_ID}    COMPLETED
    Should Be Equal     ${completed_order}[status]    COMPLETED
    
    Log                 Successfully validated status transition: CREATED -> PICKING -> DELIVERING -> COMPLETED