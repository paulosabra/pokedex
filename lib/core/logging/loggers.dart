/// Logger names of the hierarchy (PRD §11.2, Tech Spec §9).
///
/// Every logger is a child of [root], so attaching to `Logger(root)` observes
/// the whole app.
abstract final class LoggerNames {
  static const root = 'pokedex';
  static const app = '$root.app';
  static const api = '$root.api';
  static const repository = '$root.repository';
  static const storage = '$root.storage';
  static const listController = '$root.controller.list';
  static const detailController = '$root.controller.detail';
  static const viewImage = '$root.view.image';

  static const all = [
    root,
    app,
    api,
    repository,
    storage,
    listController,
    detailController,
    viewImage,
  ];
}
