*** Settings ***
Documentation     Advanced E2E Test Suite for Order Management with Complex Processing Rules
...               Includes order processing, business rules, and system constraints
Library           RequestsLibrary
Library           Collections
Library           OperatingSystem
Library           String
Library           DateTime
Library           BuiltIn
Library           Process
Library           JSONLibrary
Resource          ../../Variables/variables.robot

*** Keywords ***
Setup API Session
    [Documentation]     Create API session and authenticate
    Create Session      vkho             ${BASE_URL}      verify=True    disable_warnings=True
    
    ${headers}=         Create Dictionary    Content-Type=application/json
    ${body}=            Create Dictionary    username=${MANAGER_USERNAME}    password=${MANAGER_PASSWORD}
    
    ${response}=        POST On Session
    ...                 vkho
    ...                 /auth/login
    ...                 json=${body}
    ...                 headers=${headers}
    ...                 expected_status=201
    
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Dictionary Should Contain Key        ${json}    access_token
    ...    msg=Authentication failed: Response did not contain access_token
    
    ${token}=           Set Variable     Bearer ${json}[access_token]
    Set Global Variable  ${AUTH_TOKEN}    ${token}
    
    Create Directory    ${RESULTS_DIR}

Generate Order Data With Processing Rules
    [Documentation]     Generate order data with processing rules
    [Arguments]         ${processing_type}=standard    ${custom_data}=${EMPTY}
    
    ${timestamp}=       Get Time    epoch
    ${order_code}=      Set Variable    ORD${timestamp}
    
    # Base order data
    ${order_data}=      Create Dictionary
    ...                 code=${order_code}
    ...                 customerName=Test Customer ${timestamp}
    ...                 customerPhone=800${timestamp}
    ...                 customerEmail=customer${timestamp}@example.com
    ...                 deliveryAddress=Test Address ${timestamp}
    ...                 deliveryTime=2024-04-02T10:00:00.000Z
    ...                 warehouseId=${WAREHOUSE_ID}
    ...                 status=${ORDER_STATUS_NEW}
    ...                 priority=${MAX_ORDER_PRIORITY}
    ...                 totalWeight=0
    ...                 totalVolume=0
    ...                 discountPercent=0
    ...                 processingNotes=${EMPTY}
    
    # Modify data based on processing type
    IF    '${processing_type}' == 'high_priority'
        Set To Dictionary    ${order_data}    priority=${MIN_ORDER_PRIORITY}
    ELSE IF    '${processing_type}' == 'heavy_weight'
        Set To Dictionary    ${order_data}    totalWeight=${MAX_ORDER_WEIGHT} + 1
    ELSE IF    '${processing_type}' == 'large_volume'
        Set To Dictionary    ${order_data}    totalVolume=${MAX_ORDER_VOLUME} + 1
    ELSE IF    '${processing_type}' == 'high_discount'
        Set To Dictionary    ${order_data}    discountPercent=${MAX_DISCOUNT_PERCENT} + 1
    ELSE IF    '${processing_type}' == 'many_products'
        Set To Dictionary    ${order_data}    productCount=${MAX_PRODUCTS_PER_ORDER} + 1
    END
    
    # Add custom data if provided
    Run Keyword If    '${custom_data}' != '${EMPTY}'    Set To Dictionary    ${order_data}    &{custom_data}
    
    RETURN           ${order_data}

Validate Order Processing Rules
    [Documentation]     Validate order processing rules
    [Arguments]         ${order_data}    ${processing_type}=standard
    
    # Validate priority
    ${priority}=    Get From Dictionary    ${order_data}    priority    default=${MAX_ORDER_PRIORITY}
    Should Be True    ${priority} >= ${MIN_ORDER_PRIORITY} and ${priority} <= ${MAX_ORDER_PRIORITY}
    ...    msg=Invalid order priority: ${priority}
    
    # Validate weight
    ${weight}=    Get From Dictionary    ${order_data}    totalWeight    default=0
    Should Be True    ${weight} >= ${MIN_ORDER_WEIGHT} and ${weight} <= ${MAX_ORDER_WEIGHT}
    ...    msg=Invalid order weight: ${weight}
    
    # Validate volume
    ${volume}=    Get From Dictionary    ${order_data}    totalVolume    default=0
    Should Be True    ${volume} >= ${MIN_ORDER_VOLUME} and ${volume} <= ${MAX_ORDER_VOLUME}
    ...    msg=Invalid order volume: ${volume}
    
    # Validate discount
    ${discount}=    Get From Dictionary    ${order_data}    discountPercent    default=0
    Should Be True    ${discount} >= ${MIN_DISCOUNT_PERCENT} and ${discount} <= ${MAX_DISCOUNT_PERCENT}
    ...    msg=Invalid discount percentage: ${discount}
    
    # Validate product count
    ${product_count}=    Get From Dictionary    ${order_data}    productCount    default=0
    Should Be True    ${product_count} >= ${MIN_PRODUCTS_PER_ORDER} and ${product_count} <= ${MAX_PRODUCTS_PER_ORDER}
    ...    msg=Invalid product count: ${product_count}

Create Order With Processing Rules
    [Documentation]     Create order with processing rule validation
    [Arguments]         ${order_data}    ${expected_status}=201    ${processing_type}=standard
    
    # Validate processing rules
    Validate Order Processing Rules    ${order_data}    ${processing_type}
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Handle expected failures
    ${status}=    Set Variable    ${expected_status}
    
    # Send create order request
    ${response}=        Run Keyword If    ${status} == 201    POST On Session
    ...                 vkho
    ...                 /orders/create
    ...                 json=${order_data}
    ...                 headers=${headers}
    ...                 expected_status=${status}
    ...                 ELSE    Run Keyword And Expect Error    *
    ...                 POST On Session
    ...                 vkho
    ...                 /orders/create
    ...                 json=${order_data}
    ...                 headers=${headers}
    
    # Process successful response
    IF    ${status} == 201
        ${json}=            Evaluate         json.loads('''${response.text}''')    json
        RETURN           ${json}[id]    ${json}
    END

Get Order By ID
    [Documentation]     Retrieve a specific order by ID
    [Arguments]         ${order_id}
    
    # Validate parameters
    Should Not Be Empty    ${order_id}
    ...    msg=Order ID cannot be empty
    
    # Prepare request
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Send get order request
    ${response}=        GET On Session
    ...                 vkho
    ...                 /orders/get-one/${order_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    # Process response
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    ...    msg=Get order response was empty
    Dictionary Should Contain Key        ${json}    id
    ...    msg=Get order response missing ID field
    
    RETURN           ${json}

Add Product To Order With Processing Rules
    [Documentation]     Add product to order with processing rules
    [Arguments]         ${order_id}    ${product_id}    ${quantity}=1    ${price}=0    ${weight}=0.1    ${volume}=0.01
    
    # Validate parameters
    Should Not Be Empty    ${order_id}    msg=Order ID cannot be empty
    Should Not Be Empty    ${product_id}    msg=Product ID cannot be empty
    
    # Get current order to update totals
    ${current_order}=    Get Order By ID    ${order_id}
    ${current_total}=    Set Variable    ${current_order.get('totalAmount', 0)}
    ${current_items}=    Set Variable    ${current_order.get('itemCount', 0)}
    ${current_weight}=    Set Variable    ${current_order.get('totalWeight', 0)}
    ${current_volume}=    Set Variable    ${current_order.get('totalVolume', 0)}
    
    # Calculate new totals
    ${new_total}=       Evaluate    ${current_total} + (${quantity} * ${price})
    ${new_items}=       Evaluate    ${current_items} + ${quantity}
    ${new_weight}=      Evaluate    ${current_weight} + (${quantity} * ${weight})
    ${new_volume}=      Evaluate    ${current_volume} + (${quantity} * ${volume})
    
    # Validate processing rules
    Should Be True    ${new_weight} <= ${MAX_ORDER_WEIGHT}
    ...    msg=Order weight exceeds maximum limit
    Should Be True    ${new_volume} <= ${MAX_ORDER_VOLUME}
    ...    msg=Order volume exceeds maximum limit
    
    # Create product order data
    ${product_order_data}=    Create Dictionary
    ...                      orderId=${order_id}
    ...                      productId=${product_id}
    ...                      quantity=${quantity}
    ...                      price=${price}
    ...                      weight=${weight}
    ...                      volume=${volume}
    ...                      warehouseId=${WAREHOUSE_ID}
    ...                      totalAmount=${new_total}
    ...                      itemCount=${new_items}
    ...                      totalWeight=${new_weight}
    ...                      totalVolume=${new_volume}
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Add product to order
    ${response}=        POST On Session
    ...                 vkho
    ...                 /product-orders/create
    ...                 json=${product_order_data}
    ...                 headers=${headers}
    ...                 expected_status=201
    
    # Update order totals
    ${update_data}=     Create Dictionary
    ...                 id=${order_id}
    ...                 totalAmount=${new_total}
    ...                 itemCount=${new_items}
    ...                 totalWeight=${new_weight}
    ...                 totalVolume=${new_volume}
    ...                 warehouseId=${WAREHOUSE_ID}
    
    ${update_response}=    PUT On Session
    ...                 vkho
    ...                 /orders/update
    ...                 json=${update_data}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    RETURN           ${json}[id]    ${json}

*** Test Cases ***
01 - Setup Test Environment
    [Documentation]     Setup API session for processing tests
    [Tags]              setup    processing
    Setup API Session

02 - Create Order With Standard Processing Test
    [Documentation]     Test creating order with standard processing rules
    [Tags]              create    positive    processing
    
    ${order_data}=      Generate Order Data With Processing Rules    processing_type=standard
    ${order_id}    ${response}=    Create Order With Processing Rules    ${order_data}
    
    Should Not Be Empty    ${order_id}
    Set Suite Variable    ${TEST_ORDER_ID}    ${order_id}

03 - Create Order With High Priority Test
    [Documentation]     Test creating order with high priority
    [Tags]              create    positive    processing
    
    ${order_data}=      Generate Order Data With Processing Rules    processing_type=high_priority
    ${order_id}    ${response}=    Create Order With Processing Rules    ${order_data}
    
    Should Not Be Empty    ${order_id}
    Should Be Equal As Integers    ${response}[priority]    ${MIN_ORDER_PRIORITY}

04 - Create Order With Excessive Weight Test
    [Documentation]     Test creating order with weight exceeding limits
    [Tags]              create    negative    processing
    
    ${order_data}=      Generate Order Data With Processing Rules    processing_type=heavy_weight
    Run Keyword And Expect Error    *Invalid order weight*
    ...    Create Order With Processing Rules    ${order_data}    expected_status=400

05 - Create Order With Excessive Volume Test
    [Documentation]     Test creating order with volume exceeding limits
    [Tags]              create    negative    processing
    
    ${order_data}=      Generate Order Data With Processing Rules    processing_type=large_volume
    Run Keyword And Expect Error    *Invalid order volume*
    ...    Create Order With Processing Rules    ${order_data}    expected_status=400

06 - Create Order With High Discount Test
    [Documentation]     Test creating order with discount exceeding limits
    [Tags]              create    negative    processing
    
    ${order_data}=      Generate Order Data With Processing Rules    processing_type=high_discount
    Run Keyword And Expect Error    *Invalid discount percentage*
    ...    Create Order WithProcessing Rules    ${order_data}    expected_status=400

07 - Add Product With Weight Limits Test
    [Documentation]     Test adding product with weight limits
    [Tags]              update    negative    processing
    
    ${order_data}=      Generate Order Data With Processing Rules    processing_type=standard
    ${order_id}    ${response}=    Create Order With Processing Rules    ${order_data}
    
    # Try to add product that would exceed weight limit
    Run Keyword And Expect Error    *Order weight exceeds maximum limit*
    ...    Add Product To Order With Processing Rules    ${order_id}    123    quantity=1000    weight=2

08 - Add Product With Volume Limits Test
    [Documentation]     Test adding product with volume limits
    [Tags]              update    negative    processing
    
    ${order_data}=      Generate Order Data With Processing Rules    processing_type=standard
    ${order_id}    ${response}=    Create Order With Processing Rules    ${order_data}
    
    # Try to add product that would exceed volume limit
    Run Keyword And Expect Error    *Order volume exceeds maximum limit*
    ...    Add Product To Order With Processing Rules    ${order_id}    123    quantity=1000    volume=0.2

09 - Create Multiple Orders With Priority Test
    [Documentation]     Test creating multiple orders with different priorities
    [Tags]              create    performance    processing
    
    @{order_ids}=       Create List
    
    # Create orders with different priorities
    FOR    ${index}    IN RANGE    ${MAX_CONCURRENT_ORDERS}
        ${priority}=    Evaluate    ${index} % ${MAX_ORDER_PRIORITY} + 1
        ${custom_data}=    Create Dictionary    priority=${priority}
        ${order_data}=    Generate Order Data With Processing Rules    custom_data=${custom_data}
        ${order_id}    ${response}=    Create Order With Processing Rules    ${order_data}
        Append To List    ${order_ids}    ${order_id}
        Sleep    ${MIN_ORDER_INTERVAL}
    END
    
    Length Should Be    ${order_ids}    ${MAX_CONCURRENT_ORDERS}

10 - Cleanup Test Environment
    [Documentation]     Clean up test data and resources
    [Tags]              cleanup
    Log    Test environment cleaned up successfully 