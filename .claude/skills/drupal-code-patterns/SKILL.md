---
name: drupal-code-patterns
description: >-
  Reference patterns and templates for common Drupal 10/11 development tasks:
  forms, block plugins, routing, controllers, hooks, caching, Batch API,
  Queue API, and AJAX forms. Use when implementing these patterns in custom
  modules. For module scaffolding (info.yml, services.yml), use drupal-module-scaffold.
  Examples:
  - user: "create a form" -> use Form template pattern
  - user: "add a block plugin" -> use Block Plugin template
  - user: "implement hook_form_alter" -> use Hooks patterns
  - user: "necesito un formulario con AJAX" -> use AJAX Form pattern
  - user: "proceso batch para importar datos" -> use Batch API pattern
  Never use for module scaffolding (use drupal-module-scaffold) or theming (use drupal-theme agent).
---

## Service Class

```php
<?php

declare(strict_types=1);

namespace Drupal\mymodule\Service;

use Drupal\Core\Entity\EntityTypeManagerInterface;
use Drupal\Core\Session\AccountProxyInterface;
use Psr\Log\LoggerInterface;

final class MyService {

  public function __construct(
    private readonly EntityTypeManagerInterface $entityTypeManager,
    private readonly AccountProxyInterface $currentUser,
    private readonly LoggerInterface $logger,
  ) {}

  public function process(string $input): array {
    if (empty($input)) {
      throw new \InvalidArgumentException('Input cannot be empty.');
    }
    $this->logger->info('Processing: @input', ['@input' => $input]);
    return ['result' => $input];
  }

}
```

## Form (FormBase)

**Reference:** `$DDEV_DOCROOT/modules/contrib/examples/modules/form_api_example`

```php
<?php

declare(strict_types=1);

namespace Drupal\mymodule\Form;

use Drupal\Core\Form\FormBase;
use Drupal\Core\Form\FormStateInterface;
use Drupal\mymodule\Service\MyService;
use Symfony\Component\DependencyInjection\ContainerInterface;

final class MyForm extends FormBase {

  public function __construct(
    private readonly MyService $myService,
  ) {}

  public static function create(ContainerInterface $container): self {
    return new self($container->get('mymodule.my_service'));
  }

  public function getFormId(): string {
    return 'mymodule_my_form';
  }

  public function buildForm(array $form, FormStateInterface $form_state): array {
    $form['name'] = [
      '#type' => 'textfield',
      '#title' => $this->t('Name'),
      '#required' => TRUE,
      '#maxlength' => 255,
    ];
    $form['actions'] = [
      '#type' => 'actions',
      'submit' => ['#type' => 'submit', '#value' => $this->t('Submit')],
    ];
    return $form;
  }

  public function validateForm(array &$form, FormStateInterface $form_state): void {
    if (strlen($form_state->getValue('name')) < 3) {
      $form_state->setErrorByName('name', $this->t('Name must be at least 3 characters.'));
    }
  }

  public function submitForm(array &$form, FormStateInterface $form_state): void {
    $this->myService->process($form_state->getValue('name'));
    $this->messenger()->addStatus($this->t('Form submitted successfully.'));
  }

}
```

## Block Plugin

**Reference:** `$DDEV_DOCROOT/modules/contrib/examples/modules/block_example`

```php
<?php

declare(strict_types=1);

namespace Drupal\mymodule\Plugin\Block;

use Drupal\Core\Block\BlockBase;
use Drupal\Core\Plugin\ContainerFactoryPluginInterface;
use Drupal\mymodule\Service\MyService;
use Symfony\Component\DependencyInjection\ContainerInterface;

/**
 * Provides my custom block.
 *
 * @Block(
 *   id = "mymodule_my_block",
 *   admin_label = @Translation("My Block"),
 *   category = @Translation("Custom"),
 * )
 */
final class MyBlock extends BlockBase implements ContainerFactoryPluginInterface {

  public function __construct(
    array $configuration,
    $plugin_id,
    $plugin_definition,
    private readonly MyService $myService,
  ) {
    parent::__construct($configuration, $plugin_id, $plugin_definition);
  }

  public static function create(ContainerInterface $container, array $configuration, $plugin_id, $plugin_definition): self {
    return new self($configuration, $plugin_id, $plugin_definition, $container->get('mymodule.my_service'));
  }

  public function build(): array {
    return [
      '#theme' => 'mymodule_block',
      '#data' => $this->myService->getData(),
      '#cache' => [
        'contexts' => ['user'],
        'tags' => ['mymodule:data'],
        'max-age' => 3600,
      ],
    ];
  }

}
```

## Routing & Controllers

**Reference:** `$DDEV_DOCROOT/modules/contrib/examples/modules/page_example`

### mymodule.routing.yml

```yaml
mymodule.example_page:
  path: '/mymodule/example/{parameter}'
  defaults:
    _controller: '\Drupal\mymodule\Controller\ExampleController::content'
    _title: 'Example Page'
    parameter: 'default_value'
  requirements:
    _permission: 'access content'
    parameter: '\d+'

mymodule.form_page:
  path: '/mymodule/form'
  defaults:
    _form: '\Drupal\mymodule\Form\MyForm'
    _title: 'My Form'
  requirements:
    _permission: 'access mymodule'
```

### Controller

```php
<?php

declare(strict_types=1);

namespace Drupal\mymodule\Controller;

use Drupal\Core\Controller\ControllerBase;
use Drupal\mymodule\Service\MyService;
use Symfony\Component\DependencyInjection\ContainerInterface;

final class ExampleController extends ControllerBase {

  public function __construct(private readonly MyService $myService) {}

  public static function create(ContainerInterface $container): self {
    return new self($container->get('mymodule.my_service'));
  }

  public function content(string $parameter): array {
    return [
      '#theme' => 'mymodule_example',
      '#data' => $this->myService->getData($parameter),
      '#cache' => [
        'contexts' => ['url.path'],
        'tags' => ['mymodule:data'],
        'max-age' => 3600,
      ],
    ];
  }

}
```

## Hooks

**Reference:** `$DDEV_DOCROOT/modules/contrib/examples/modules/hooks_example`

```php
<?php

use Drupal\Core\Form\FormStateInterface;

/**
 * Implements hook_form_alter().
 */
function mymodule_form_alter(array &$form, FormStateInterface $form_state, string $form_id): void {
  if ($form_id === 'node_article_form') {
    $form['title']['#description'] = t('Enter a catchy title for your article.');
  }
}

/**
 * Implements hook_theme().
 */
function mymodule_theme(array $existing, string $type, string $theme, string $path): array {
  return [
    'mymodule_custom' => [
      'variables' => ['title' => '', 'items' => []],
      'template' => 'mymodule-custom',
    ],
  ];
}
```

## Caching Best Practices

Every render array MUST have cache metadata:

```php
public function build(): array {
  return [
    '#markup' => $this->getData(),
    '#cache' => [
      'contexts' => ['user', 'url.path', 'url.query_args'],
      'tags' => ['node:1', 'node_list', 'mymodule:data'],
      'max-age' => 3600,
    ],
  ];
}
```

For dynamic user-specific content, use lazy builders:

```php
$build['dynamic_part'] = [
  '#lazy_builder' => ['mymodule.lazy_builder:build', [$entity_id]],
  '#create_placeholder' => TRUE,
];
```

For comprehensive caching strategies, delegate to the **drupal-perf** agent.

## Batch API

**Reference:** `$DDEV_DOCROOT/modules/contrib/examples/modules/batch_example`

```php
function mymodule_batch_process(array $items, array &$context): void {
  if (!isset($context['sandbox']['progress'])) {
    $context['sandbox']['progress'] = 0;
    $context['sandbox']['max'] = count($items);
  }
  $batch_size = 10;
  $slice = array_slice($items, $context['sandbox']['progress'], $batch_size);
  foreach ($slice as $item) {
    // Process item...
    $context['sandbox']['progress']++;
  }
  $context['finished'] = $context['sandbox']['progress'] / $context['sandbox']['max'];
}

function mymodule_execute_batch(): void {
  $batch = [
    'title' => t('Processing items...'),
    'operations' => [['mymodule_batch_process', [range(1, 1000)]]],
    'finished' => 'mymodule_batch_finished',
    'progress_message' => t('Processed @current of @total.'),
  ];
  batch_set($batch);
}
```

## Queue API

**Reference:** `$DDEV_DOCROOT/modules/contrib/examples/modules/queue_example`

```php
<?php

declare(strict_types=1);

namespace Drupal\mymodule\Plugin\QueueWorker;

use Drupal\Core\Queue\QueueWorkerBase;

/**
 * Process queue items.
 *
 * @QueueWorker(
 *   id = "mymodule.email_sender",
 *   title = @Translation("Email sender"),
 *   cron = {"time" = 60}
 * )
 */
class EmailQueueWorker extends QueueWorkerBase {

  public function processItem($data): void {
    \Drupal::service('plugin.manager.mail')->mail(
      'mymodule', 'notification', $data['to'], $data['langcode'], $data['params']
    );
  }

}
```

Adding items: `\Drupal::queue('mymodule.email_sender')->createItem($data);`

## AJAX Forms

**Reference:** `$DDEV_DOCROOT/modules/contrib/examples/modules/ajax_example`

```php
<?php

declare(strict_types=1);

namespace Drupal\mymodule\Form;

use Drupal\Core\Form\FormBase;
use Drupal\Core\Form\FormStateInterface;

final class AjaxExampleForm extends FormBase {

  public function getFormId(): string {
    return 'mymodule_ajax_example';
  }

  public function buildForm(array $form, FormStateInterface $form_state): array {
    $form['category'] = [
      '#type' => 'select',
      '#title' => $this->t('Category'),
      '#options' => ['fruits' => $this->t('Fruits'), 'vegetables' => $this->t('Vegetables')],
      '#ajax' => [
        'callback' => '::updateItemsCallback',
        'wrapper' => 'items-wrapper',
        'event' => 'change',
      ],
    ];
    $form['items_wrapper'] = [
      '#type' => 'container',
      '#attributes' => ['id' => 'items-wrapper'],
    ];
    $category = $form_state->getValue('category', 'fruits');
    $form['items_wrapper']['item'] = [
      '#type' => 'select',
      '#title' => $this->t('Item'),
      '#options' => $this->getItemsByCategory($category),
    ];
    $form['actions'] = [
      '#type' => 'actions',
      'submit' => ['#type' => 'submit', '#value' => $this->t('Submit')],
    ];
    return $form;
  }

  public function updateItemsCallback(array &$form, FormStateInterface $form_state): array {
    return $form['items_wrapper'];
  }

  private function getItemsByCategory(string $category): array {
    $items = [
      'fruits' => ['apple' => 'Apple', 'banana' => 'Banana'],
      'vegetables' => ['carrot' => 'Carrot', 'broccoli' => 'Broccoli'],
    ];
    return $items[$category] ?? [];
  }

  public function submitForm(array &$form, FormStateInterface $form_state): void {
    $this->messenger()->addStatus($this->t('Form submitted.'));
  }

}
```
