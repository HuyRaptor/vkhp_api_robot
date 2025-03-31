*** Settings ***
Documentation     Test Suite for Bulk Order Operations in vKho API
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
${BULK_ORDER_IDS}       @{EMPTY}

*** Keywords ***
Setup API Session
    Create Session      vkho             ${BASE_URL}      verify=True    disable_warnings=True
    ${headers}=         Create Dictionary    Content-Type=application/json
    ${body}=            Create Dictionary    username=${USERNAME}    password=${PASSWORD}
    ${response}=        POST On Session    vkho    /auth/login    json=${body}    headers=${headers}    expected_status=201
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    ${token}=           Set Variable     Bearer ${json}[access_token]
    Set Global Variable  ${AUTH_TOKEN}    ${token}
    Create Directory    ${RESULTS_DIR}

Generate Bulk Order Data
    [Arguments]         ${count}
    ${bulk_orders}=     Create List
    FOR    ${i}    IN RANGE    ${count}
        ${timestamp}=   Evaluate         int(time.time())    time
        ${order_code}=  Set Variable     ORDBULK${timestamp}${i}
        ${product_order}=    Create Dictionary    total=5    boothCode=BOOTH${timestamp}    sku=SKU${timestamp}
        ${product_orders}=   Create List      ${product_order}
        ${order_data}=  Create Dictionary
        ...             nameCustomer=Bulk Test ${timestamp}${i}
        ...             code=${order_code}
        ...             boothCode=BOOTH${timestamp}
        ...             deliveryAdress=Test Address
        ...             deliveryTime=2025-04-01T12:00:00.000Z
        ...             warehouseId=${WAREHOUSE_ID}
        ...             productOrders=${product_orders}
        Append To List    ${bulk_orders}    ${order_data}
    END
    RETURN            ${bulk_orders}

Bulk Create Orders
    [Arguments]         ${orders}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        POST On Session    vkho    /orders/bulk-create    json=${orders}    headers=${headers}    expected_status=201
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    RETURN            ${json}

Bulk Delete Orders
    [Arguments]         ${order_ids}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${body}=            Create Dictionary    ids=${order_ids}
    ${response}=        DELETE On Session    vkho    /orders/bulk-delete    json=${body}    headers=${headers}    expected_status=200
    RETURN            ${TRUE}

*** Test Cases ***
01 - Setup Environment
    [Tags]              setup
    Setup API Session

02 - Test Bulk Order Creation
    [Documentation]     Test creating multiple orders in bulk
    [Tags]              bulk    create    positive
    ${bulk_orders}=     Generate Bulk Order Data    3
    ${response}=        Bulk Create Orders    ${bulk_orders}
    ${data_length}=     Get Length    ${response}
    Should Be Equal As Integers    ${data_length}    3
    
    FOR    ${order}    IN    @{response}
        Append To List    ${BULK_ORDER_IDS}    ${order}[id]
    END
    Log                 Successfully created ${data_length} orders in bulk

03 - Test Bulk Order Deletion
    [Documentation]     Test deleting multiple orders in bulk
    [Tags]              bulk    delete    positive
    Run Keyword If      "${BULK_ORDER_IDS}" == "@{EMPTY}"    Fail    No orders created for deletion test
    ${result}=          Bulk Delete Orders    ${BULK_ORDER_IDS}
    Should Be True      ${result}
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    FOR    ${order_id}    IN    @{BULK_ORDER_IDS}
        ${response}=    GET On Session    vkho    /orders/get-one/${order_id}    headers=${headers}    expected_status=404
    END
    Log                 Successfully deleted ${BULK_ORDER_IDS.__len__()} orders in bulk